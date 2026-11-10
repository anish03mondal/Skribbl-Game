const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');
const socketio = require('socket.io');
const Room = require('./models/Room');
const getWord = require('./api/getWord');

// Process-level crash prevention to ensure active games never drop abruptly
process.on('uncaughtException', (err) => {
  console.error('🛡️ Uncaught Exception caught safely:', err);
});

process.on('unhandledRejection', (reason) => {
  console.error('🛡️ Unhandled Rejection caught safely:', reason);
});

const app = express();
const server = http.createServer(app);
const io = socketio(server);
const port = process.env.PORT || 3000;

app.use(express.json());

// Enable CORS for global multiplayer connections from any origin
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  next();
});

// Serve static Flutter Web game files from public directory
const candidatePublicPaths = [
  path.resolve(__dirname, 'public'),
  path.resolve(process.cwd(), 'public'),
  path.resolve(process.cwd(), 'Server', 'public'),
  path.resolve(__dirname, '..', 'public'),
];
const publicPath = candidatePublicPaths.find(p => fs.existsSync(path.join(p, 'index.html'))) || path.resolve(__dirname, 'public');

if (fs.existsSync(publicPath)) {
  app.use(express.static(publicPath, {
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('.wasm')) {
        res.setHeader('Content-Type', 'application/wasm');
      }
    }
  }));
}

app.get('/health', (req, res) => {
  res.json({
    status: 'online',
    uptime: process.uptime(),
    rooms: inMemoryRooms.size,
    dbConnected: isDbConnected,
    hasWebClient: fs.existsSync(path.join(publicPath, 'index.html')),
    publicPath: publicPath,
  });
});

// Root & SPA Fallback: Serve Flutter web app if built, otherwise show server status message
app.get('/', (req, res) => {
  const indexPath = path.join(publicPath, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.send('🎮 Skribbl Multiplayer Game Server is running live!');
  }
});

// In-memory room store fallback when MongoDB is not running
let isDbConnected = false;
const inMemoryRooms = new Map();

class InMemoryRoom {
  constructor(data = {}) {
    this.name = data.name || '';
    this.word = data.word || '';
    this.wordChoices = data.wordChoices ? [...data.wordChoices] : [];
    this.isChoosingWord = data.isChoosingWord || false;
    this.nickname = data.nickname || '';
    this.occupancy = Number(data.occupancy) || 4;
    this.maxRounds = Number(data.maxRounds) || 2;
    this.currentRound = Number(data.currentRound) || 1;
    this.players = data.players ? [...data.players] : [];
    this.isJoin = data.isJoin !== undefined ? data.isJoin : true;
    this.turn = data.turn || null;
    this.turnIndex = Number(data.turnIndex) || 0;
    this.gussedUserCtr = Number(data.gussedUserCtr) || 0;
    this.isEndingTurn = data.isEndingTurn || false;
    this.isGameOver = data.isGameOver || false;
    this.guessedUsers = data.guessedUsers ? new Set(data.guessedUsers) : new Set();
  }
  async save() {
    inMemoryRooms.set(this.name, this);
    return this;
  }
}

const RoomAdapter = {
  async findOne(query) {
    if (isDbConnected) {
      try {
        const doc = await Room.findOne(query);
        if (doc) return doc;
      } catch (err) {
        console.warn('MongoDB query error, falling back to in-memory store:', err.message);
      }
    }
    if (query.name) {
      return inMemoryRooms.get(query.name) || null;
    }
    if (query['players.socketID']) {
      const socketID = query['players.socketID'];
      for (const room of inMemoryRooms.values()) {
        if (room.players && room.players.some((p) => p.socketID === socketID)) {
          return room;
        }
      }
      return null;
    }
    return null;
  },
  async deleteOne(query) {
    if (query.name) {
      inMemoryRooms.delete(query.name);
    }
    if (isDbConnected) {
      try {
        await Room.deleteOne(query);
      } catch (err) {
        console.warn('MongoDB delete error:', err.message);
      }
    }
  },
  create(data = {}) {
    if (isDbConnected) {
      return new Room(data);
    }
    return new InMemoryRoom(data);
  },
};

// Generates 3 distinct words for drawer selection
const get3Words = () => {
  const words = new Set();
  while (words.size < 3) {
    words.add(getWord());
  }
  return Array.from(words);
};

// Start word selection for the current turn
async function startTurnWordSelection(room) {
  if (!room || !room.players || room.players.length === 0) return;

  // Make sure turn index and turn drawer are strictly valid
  if (room.turnIndex === undefined || room.turnIndex >= room.players.length || room.turnIndex < 0) {
    room.turnIndex = 0;
  }
  room.turn = room.players[room.turnIndex] || room.players[0];

  const choices = get3Words();
  room.wordChoices = choices;
  room.word = '';
  room.isChoosingWord = true;
  room.gussedUserCtr = 0;
  if (!room.guessedUsers) {
    room.guessedUsers = new Set();
  } else {
    room.guessedUsers.clear();
  }
  await room.save();

  // Clear canvas for everyone
  io.to(room.name).emit('clear-screen', '');

  // Notify room that the drawer is choosing a word
  io.to(room.name).emit('start-word-selection', {
    roomName: room.name,
    drawerNickname: room.turn ? room.turn.nickname : 'Player',
    drawerSocketId: room.turn ? room.turn.socketID : '',
    turnIndex: room.turnIndex,
    currentRound: room.currentRound,
    maxRounds: room.maxRounds,
    wordChoices: choices,
    players: room.players,
    turn: room.turn,
  });
}

// End the current turn and transition to the next player
async function endTurnAndAdvance(room) {
  if (!room || room.isEndingTurn || room.isGameOver) return;
  room.isEndingTurn = true;

  if (!room.players || room.players.length === 0) {
    room.isEndingTurn = false;
    return;
  }

  // If only 1 player remains, wait for opponent to reconnect rather than rushing rounds
  if (room.players.length === 1) {
    room.isEndingTurn = false;
    io.to(room.name).emit('msg', {
      username: 'System',
      msg: '⏳ Waiting for opponent to reconnect...',
      color: 'yellow',
    });
    return;
  }

  const oldWord = room.word;
  const idx = room.turnIndex || 0;
  const nextIdx = (idx + 1) % room.players.length;
  if (nextIdx === 0) {
    room.currentRound += 1;
  }

  if (room.currentRound <= room.maxRounds) {
    room.turnIndex = nextIdx;
    room.turn = room.players[room.turnIndex] || room.players[0];
    await room.save();

    // Broadcast that the turn ended and reveal the word
    io.to(room.name).emit('turn-ended', {
      oldWord: oldWord,
      nextDrawer: room.turn ? room.turn.nickname : 'Player',
    });

    // After 3.5 seconds, start the word selection for next turn
    setTimeout(async () => {
      let freshRoom = await RoomAdapter.findOne({ name: room.name });
      if (freshRoom && !freshRoom.isGameOver) {
        freshRoom.isEndingTurn = false;
        await startTurnWordSelection(freshRoom);
      }
    }, 3500);
  } else {
    room.isEndingTurn = false;
    room.isGameOver = true;
    await room.save();
    io.to(room.name).emit('show-leaderboard', room.players);
  }
}

// MongoDB connection
const DB = process.env.MONGO_URI || 'mongodb+srv://anish03mondal:Anish12345@cluster0.knr6sql.mongodb.net/skribbl';

mongoose.set('bufferCommands', false);

mongoose
  .connect(DB, {
    serverSelectionTimeoutMS: 3000,
  })
  .then(() => {
    isDbConnected = true;
    console.log('✅ MongoDB Connected');
  })
  .catch((err) => {
    isDbConnected = false;
    console.log('⚠️ MongoDB not connected:', err.message);
    console.log('⚡ Switched to IN-MEMORY storage. Game rooms will work smoothly without a database!');
  });

function levenshteinDistance(a, b) {
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;
  const matrix = [];
  for (let i = 0; i <= b.length; i++) matrix[i] = [i];
  for (let j = 0; j <= a.length; j++) matrix[0][j] = j;
  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          Math.min(matrix[i][j - 1] + 1, matrix[i - 1][j] + 1)
        );
      }
    }
  }
  return matrix[b.length][a.length];
}

io.on('connection', (socket) => {
  console.log('🟢 A user connected:', socket.id);

  socket.on('create-game', async ({ nickname, name, occupancy, maxRounds }) => {
    try {
      let existingRoom = await RoomAdapter.findOne({ name });
      if (existingRoom) {
        // If the room has 0 players, or game is over, or abandoned -> clean it up so code can be reused!
        const isFinished =
          existingRoom.isGameOver ||
          existingRoom.currentRound > existingRoom.maxRounds ||
          !existingRoom.players ||
          existingRoom.players.length === 0;

        if (isFinished) {
          console.log(`♻️ Cleaning up finished/empty room "${name}" for fresh game`);
          await RoomAdapter.deleteOne({ name });
          existingRoom = null;
        } else {
          // If the party leader is reconnecting after temporary network drop
          const existingPlayer = existingRoom.players.find((p) => p.nickname === nickname);
          if (existingPlayer) {
            console.log(`🔄 Leader "${nickname}" reconnecting to room "${name}"`);
            existingPlayer.socketID = socket.id;
            socket.join(name);
            await existingRoom.save();
            socket.emit('updateRoom', existingRoom);
            if (existingRoom.word && !existingRoom.isChoosingWord) {
              socket.emit('round-started', { word: existingRoom.word, room: existingRoom });
            }
            return;
          }
          socket.emit(
            'notCorrectGame',
            'A game with this room code is currently in progress. Please choose another code or wait for it to finish.'
          );
          return;
        }
      }

      let room = RoomAdapter.create();
      room.word = '';
      room.nickname = nickname;
      room.name = name;
      room.occupancy = parseInt(occupancy, 10) || 4;
      room.maxRounds = parseInt(maxRounds, 10) || 2;
      room.currentRound = 1;
      room.turnIndex = 0;
      room.isJoin = true;
      room.isGameOver = false;

      const player = {
        socketID: socket.id,
        nickname,
        isPartyLeader: true,
        points: 0,
      };
      room.players.push(player);
      room.turn = player;
      room = await room.save();

      socket.join(name);
      io.to(name).emit('updateRoom', room);
    } catch (err) {
      console.error('Error creating game:', err);
    }
  });

  socket.on('join-game', async ({ nickname, name }) => {
    try {
      let room = await RoomAdapter.findOne({ name });
      if (!room) {
        socket.emit('notCorrectGame', 'Please enter a valid room name');
        return;
      }

      // 1. Reconnection check: if this player already exists in the room, seamlessly reconnect them!
      const existingPlayer = room.players.find((p) => p.nickname === nickname);
      if (existingPlayer) {
        console.log(`🔄 Player "${nickname}" reconnecting to room "${name}"`);
        existingPlayer.socketID = socket.id;
        socket.join(name);
        await room.save();
        socket.emit('updateRoom', room);

        if (room.isChoosingWord) {
          socket.emit('start-word-selection', {
            roomName: room.name,
            drawerNickname: room.turn ? room.turn.nickname : '',
            drawerSocketId: room.turn ? room.turn.socketID : '',
            turnIndex: room.turnIndex,
            currentRound: room.currentRound,
            maxRounds: room.maxRounds,
            wordChoices: room.wordChoices || [],
            players: room.players,
            turn: room.turn,
          });
        } else if (room.word) {
          socket.emit('round-started', { word: room.word, room: room });
        }
        io.to(name).emit('updateScore', room);
        return;
      }

      // 2. Room is open for new joins
      if (room.isJoin && !room.isGameOver) {
        const player = {
          socketID: socket.id,
          nickname,
          points: 0,
        };
        room.players.push(player);
        socket.join(name);

        if (room.players.length >= room.occupancy) {
          room.isJoin = false;
          room.turnIndex = 0;
          room.turn = room.players[0];
          room = await room.save();
          io.to(name).emit('updateRoom', room);

          // All players joined -> start word selection for round 1
          await startTurnWordSelection(room);
        } else {
          room.turn = room.players[room.turnIndex];
          room = await room.save();
          io.to(name).emit('updateRoom', room);
        }
      } else {
        socket.emit('notCorrectGame', 'The game is already in progress or has ended.');
      }
    } catch (err) {
      console.error('Error joining game:', err);
    }
  });

  // Drawer chooses 1 word out of the 3 options
  socket.on('select-word', async ({ roomName, word }) => {
    try {
      let room = await RoomAdapter.findOne({ name: roomName });
      if (!room) return;
      if (!room.turn || room.turn.socketID !== socket.id) return;

      room.word = word;
      room.isChoosingWord = false;
      room.gussedUserCtr = 0;
      if (room.guessedUsers) room.guessedUsers.clear();
      await room.save();

      io.to(roomName).emit('clear-screen', '');

      io.to(roomName).emit('round-started', {
        room: room,
        word: word,
        wordLength: word.length,
        drawerNickname: room.turn.nickname,
      });
    } catch (err) {
      console.error('Error selecting word:', err);
    }
  });

  // Only the drawer can draw on canvas
  socket.on('paint', async ({ details, roomName }) => {
    const room = await RoomAdapter.findOne({ name: roomName });
    if (room && room.turn && room.turn.socketID !== socket.id) return;
    io.to(roomName).emit('points', { details });
  });

  socket.on('color-change', async ({ color, roomName }) => {
    const room = await RoomAdapter.findOne({ name: roomName });
    if (room && room.turn && room.turn.socketID !== socket.id) return;
    io.to(roomName).emit('color-change', color);
  });

  socket.on('stroke-width', async ({ value, roomName }) => {
    const room = await RoomAdapter.findOne({ name: roomName });
    if (room && room.turn && room.turn.socketID !== socket.id) return;
    io.to(roomName).emit('stroke-width', value);
  });

  socket.on('clean-screen', async (roomName) => {
    const room = await RoomAdapter.findOne({ name: roomName });
    if (room && room.turn && room.turn.socketID !== socket.id) return;
    io.to(roomName).emit('clear-screen', '');
  });

  socket.on('msg', async (data) => {
    try {
      const room = await RoomAdapter.findOne({ name: data.roomName });
      if (!room || !room.word) return;

      const userPlayer = room.players.find((p) => p.nickname === data.username);
      if (!userPlayer) return;

      // Drawer cannot guess their own drawing
      if (room.turn && room.turn.nickname === data.username) {
        return;
      }

      // Check if user already guessed this turn
      if (!room.guessedUsers) room.guessedUsers = new Set();
      if (room.guessedUsers.has(data.username)) {
        return;
      }

      const cleanMsg = data.msg.trim().toLowerCase();
      const cleanWord = room.word.trim().toLowerCase();

      if (cleanMsg === cleanWord) {
        room.guessedUsers.add(data.username);

        // Guesser points based on speed
        const timeTaken = Math.max(1, data.timeTaken || 1);
        const calculatedPoints = Math.max(50, Math.round((200 / timeTaken) * 50));
        userPlayer.points += calculatedPoints;

        // Drawer bonus: gets 50 points per correct guess
        const drawer = room.players.find((p) => p.nickname === room.turn.nickname);
        if (drawer) {
          drawer.points += 50;
        }

        room.gussedUserCtr = (room.gussedUserCtr || 0) + 1;
        await room.save();

        io.to(data.roomName).emit('msg', {
          username: data.username,
          msg: `${data.username} guessed the word!`,
          isCorrect: true,
          gussedUserCtr: room.gussedUserCtr,
        });

        // Close guess input for this player this round
        socket.emit('close-input', '');

        // Notify frontend to update score
        io.to(data.roomName).emit('updateScore', room);

        // If all guessers guessed correctly, advance immediately
        if (room.gussedUserCtr >= room.players.length - 1) {
          await endTurnAndAdvance(room);
        }
      } else {
        // Check if guess is close (Levenshtein distance of 1)
        if (cleanWord.length >= 3 && levenshteinDistance(cleanMsg, cleanWord) === 1) {
          socket.emit('close-guess', {
            msg: `"${data.msg}" is very close!`,
          });
        }

        io.to(data.roomName).emit('msg', {
          username: data.username,
          msg: data.msg,
          isCorrect: false,
          gussedUserCtr: room.gussedUserCtr || 0,
        });
      }
    } catch (err) {
      console.error('Error in msg handler:', err);
    }
  });

  socket.on('undo-stroke', (roomName) => {
    try {
      io.to(roomName).emit('undo-stroke', '');
    } catch (err) {
      console.error('Error in undo-stroke:', err);
    }
  });

  socket.on('start-game-now', async (roomName) => {
    try {
      let room = await RoomAdapter.findOne({ name: roomName });
      if (!room || !room.isJoin) return;
      if (room.players.length < 2) return;
      const leader = room.players.find((p) => p.isPartyLeader);
      if (leader && leader.socketID === socket.id) {
        room.isJoin = false;
        room.turnIndex = 0;
        room.turn = room.players[0];
        await room.save();
        io.to(roomName).emit('updateRoom', room);
        await startTurnWordSelection(room);
      }
    } catch (err) {
      console.error('Error starting game now:', err);
    }
  });

  socket.on('updateScore', async (name) => {
    try {
      const room = await RoomAdapter.findOne({ name });
      if (room) {
        io.to(name).emit('updateScore', room);
      }
    } catch (err) {
      console.log(err);
    }
  });

  socket.on('change-turn', async (name) => {
    try {
      let room = await RoomAdapter.findOne({ name });
      if (!room || room.isEndingTurn || room.isChoosingWord) return;
      await endTurnAndAdvance(room);
    } catch (err) {
      console.error('Error in change-turn:', err);
    }
  });

  socket.on('rejoin-game', async ({ nickname, roomName }) => {
    try {
      let room = await RoomAdapter.findOne({ name: roomName });
      if (!room) return;

      let player = room.players.find((p) => p.nickname === nickname);
      if (player) {
        player.socketID = socket.id;
        player.isOnline = true;
        if (player.offlineTimer) {
          clearTimeout(player.offlineTimer);
          player.offlineTimer = null;
        }
      } else if (room.players.length < room.occupancy && !room.isGameOver) {
        player = {
          socketID: socket.id,
          nickname,
          points: 0,
          isOnline: true,
        };
        room.players.push(player);
      }

      socket.join(roomName);
      await room.save();

      console.log(`✅ Player "${nickname}" seamlessly reconnected to "${roomName}"!`);
      socket.broadcast.to(roomName).emit('msg', {
        username: 'System',
        msg: `🎉 ${nickname} reconnected!`,
        color: 'green',
      });

      socket.emit('updateRoom', room);
      io.to(roomName).emit('updateScore', room);

      if (room.isChoosingWord) {
        socket.emit('start-word-selection', {
          roomName: room.name,
          drawerNickname: room.turn ? room.turn.nickname : '',
          drawerSocketId: room.turn ? room.turn.socketID : '',
          turnIndex: room.turnIndex,
          currentRound: room.currentRound,
          maxRounds: room.maxRounds,
          wordChoices: room.wordChoices || [],
          players: room.players,
          turn: room.turn,
        });
      } else if (room.word) {
        socket.emit('round-started', { word: room.word, room: room });
      }
    } catch (err) {
      console.error('Error in rejoin-game:', err);
    }
  });

  socket.on('leave-game', async ({ roomName, nickname }) => {
    try {
      let room = await RoomAdapter.findOne({ name: roomName });
      if (!room) return;

      const idx = room.players.findIndex((p) => p.nickname === nickname || p.socketID === socket.id);
      if (idx !== -1) {
        room.players.splice(idx, 1);
      }
      socket.leave(roomName);

      if (room.players.length === 0 || room.isGameOver) {
        console.log(`🧹 Room "${roomName}" cleaned up on player leave.`);
        await RoomAdapter.deleteOne({ name: roomName });
      } else {
        await room.save();
        socket.broadcast.to(roomName).emit('user-disconnected', room);
      }
    } catch (err) {
      console.error('Error in leave-game:', err);
    }
  });

  socket.on('disconnect', async () => {
    try {
      const room = await RoomAdapter.findOne({ 'players.socketID': socket.id });
      if (!room) return;

      const player = room.players.find((p) => p.socketID === socket.id);
      if (!player) return;

      const wasDrawer = room.turn && room.turn.socketID === socket.id;

      // In lobby before game starts: remove immediately
      if (room.isJoin) {
        const idx = room.players.findIndex((p) => p.socketID === socket.id);
        if (idx !== -1) room.players.splice(idx, 1);
        if (room.players.length === 0) {
          console.log(`🧹 Room "${room.name}" empty in lobby. Freeing room code.`);
          await RoomAdapter.deleteOne({ name: room.name });
          return;
        }
        await room.save();
        socket.broadcast.to(room.name).emit('user-disconnected', room);
        return;
      }

      // During active game: Apply a 25-second grace period for transient network drops!
      player.isOnline = false;
      player.disconnectedAt = Date.now();
      await room.save();

      console.log(`🔌 Player "${player.nickname}" temporarily disconnected from "${room.name}". Starting 25s grace period.`);
      socket.broadcast.to(room.name).emit('msg', {
        username: 'System',
        msg: `⚠️ ${player.nickname} disconnected. Waiting for reconnect...`,
        color: 'yellow',
      });

      // If the drawer disconnected, give 12 seconds to return before advancing turn
      if (wasDrawer && !room.isGameOver) {
        setTimeout(async () => {
          let currentRoom = await RoomAdapter.findOne({ name: room.name });
          if (!currentRoom || currentRoom.isGameOver) return;
          const currentDrawer = currentRoom.players.find((p) => p.nickname === player.nickname);
          if (currentDrawer && currentDrawer.isOnline === false) {
            console.log(`⏰ Drawer "${player.nickname}" did not return within 12s. Advancing turn.`);
            await endTurnAndAdvance(currentRoom);
          }
        }, 12000);
      }

      // Permanent prune timer after 25 seconds
      setTimeout(async () => {
        let currentRoom = await RoomAdapter.findOne({ name: room.name });
        if (!currentRoom) return;
        const pIndex = currentRoom.players.findIndex((p) => p.nickname === player.nickname);
        if (pIndex !== -1 && currentRoom.players[pIndex].isOnline === false) {
          console.log(`❌ 25s grace period expired for "${player.nickname}" in "${room.name}". Removing.`);
          currentRoom.players.splice(pIndex, 1);

          const anyOnline = currentRoom.players.some((p) => p.isOnline !== false);
          if (currentRoom.players.length === 0 || !anyOnline) {
            console.log(`🧹 No active players in "${room.name}". Deleting room.`);
            await RoomAdapter.deleteOne({ name: room.name });
            return;
          }

          if (currentRoom.players.length <= 1) {
            currentRoom.isGameOver = true;
            await currentRoom.save();
            io.to(currentRoom.name).emit('show-leaderboard', currentRoom.players);
          } else {
            await currentRoom.save();
            io.to(currentRoom.name).emit('user-disconnected', currentRoom);
          }
        }
      }, 25000);
    } catch (err) {
      console.log('Error in disconnect:', err);
    }
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://localhost:${port}`);
});

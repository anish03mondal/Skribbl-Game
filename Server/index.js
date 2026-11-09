const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const socketio = require('socket.io');
const Room = require('./models/Room');
const getWord = require('./api/getWord');

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

// Root & Health Check endpoint for cloud deployment (Render, Railway, Fly.io, etc.)
app.get('/', (req, res) => {
  res.send('🎮 Skribbl Multiplayer Game Server is running live!');
});

app.get('/health', (req, res) => {
  res.json({
    status: 'online',
    uptime: process.uptime(),
    rooms: inMemoryRooms.size,
    dbConnected: isDbConnected,
  });
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
    drawerNickname: room.turn.nickname,
    drawerSocketId: room.turn.socketID,
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
  if (room.isEndingTurn) return;
  room.isEndingTurn = true;

  const oldWord = room.word;
  const idx = room.turnIndex;
  const nextIdx = (idx + 1) % room.players.length;
  if (nextIdx === 0) {
    room.currentRound += 1;
  }

  if (room.currentRound <= room.maxRounds) {
    room.turnIndex = nextIdx;
    room.turn = room.players[room.turnIndex];
    await room.save();

    // Broadcast that the turn ended and reveal the word
    io.to(room.name).emit('turn-ended', {
      oldWord: oldWord,
      nextDrawer: room.turn.nickname,
    });

    // After 3.5 seconds, start the word selection for next turn
    setTimeout(async () => {
      let freshRoom = await RoomAdapter.findOne({ name: room.name });
      if (freshRoom) {
        freshRoom.isEndingTurn = false;
        await startTurnWordSelection(freshRoom);
      }
    }, 3500);
  } else {
    room.isEndingTurn = false;
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

io.on('connection', (socket) => {
  console.log('🟢 A user connected:', socket.id);

  socket.on('create-game', async ({ nickname, name, occupancy, maxRounds }) => {
    try {
      const existingRoom = await RoomAdapter.findOne({ name });
      if (existingRoom) {
        socket.emit('notCorrectGame', 'Room with that name already exists');
        return;
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

      if (room.isJoin) {
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
        socket.emit('notCorrectGame', 'The game is in progress, please try again later');
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

  socket.on('disconnect', async () => {
    try {
      const room = await RoomAdapter.findOne({ 'players.socketID': socket.id });
      if (!room) return;

      for (let i = 0; i < room.players.length; i++) {
        if (room.players[i].socketID === socket.id) {
          room.players.splice(i, 1);
          break;
        }
      }

      await room.save();

      // Emit leaderboard only if round is finished or 1 player left
      if (room.players.length <= 1 && room.currentRound >= room.maxRounds) {
        socket.broadcast.to(room.name).emit('show-leaderboard', room.players);
      } else {
        socket.broadcast.to(room.name).emit('user-disconnected', room);
      }
    } catch (err) {
      console.log('Error in disconnect:', err);
    }
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://localhost:${port}`);
});

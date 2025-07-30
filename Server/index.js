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

// Middleware
app.use(express.json());

// MongoDB connection
const DB = 'mongodb+srv://anish03mondal:Anish12345@cluster0.knr6sql.mongodb.net/';
mongoose.connect(DB).then(() => {
  console.log('✅ MongoDB Connected');
}).catch((err) => {
  console.log('❌ MongoDB Error:', err);
});

// --- SOCKET.IO HANDLING ---
io.on('connection', (socket) => {
  console.log('🟢 A user connected:', socket.id);

  // CREATE GAME
  socket.on('create-game', async ({ nickname, name, occupancy, maxRounds }) => {
    try {
      const existingRoom = await Room.findOne({ name });
      if (existingRoom) {
        socket.emit('notCorrectGame', 'Room with that name already exists');
        return;
      }

      let room = new Room();
      room.word = getWord();
      room.nickname = nickname;
      room.name = name;
      room.occupancy = occupancy;
      room.maxRounds = maxRounds;

      const player = {
        socketID: socket.id,
        nickname,
        isPartyLeader: true,
        points: 0,
      };
      room.players.push(player);
      room = await room.save();

      socket.join(name);
      io.to(name).emit('updateRoom', room);
    } catch (err) {
      console.error(err);
    }
  });

  // JOIN GAME
  socket.on('join-game', async ({ nickname, name }) => {
    try {
      let room = await Room.findOne({ name });
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

        if (room.players.length === room.occupancy) {
          room.isJoin = false;
        }

        room.turn = room.players[room.turnIndex];
        room = await room.save();
        io.to(name).emit('updateRoom', room);
      } else {
        socket.emit('notCorrectGame', 'The game is in progress, please try again later');
      }
    } catch (err) {
      console.error(err);
    }
  });

  // PAINT
  socket.on('paint', ({ details, roomName }) => {
    io.to(roomName).emit('points', { details });
  });

  // COLOR
  socket.on('color-change', ({ color, roomName }) => {
    io.to(roomName).emit('color-change', color);
  });

  // STROKE
  socket.on('stroke-width', ({ value, roomName }) => {
    io.to(roomName).emit('stroke-width', value);
  });

  // CLEAR
  socket.on('clean-screen', (roomName) => {
    io.to(roomName).emit('clear-screen', '');
  });

  // GUESS / MESSAGE
  socket.on('msg', async (data) => {
    try {
      const room = await Room.findOne({ name: data.roomName });
      if (!room) return;

      if (data.msg === room.word) {
        const userPlayers = room.players.filter(p => p.nickname === data.username);
        if (data.timeTaken !== 0) {
          userPlayers[0].points += Math.round((200 / data.timeTaken) * 10);
        }

        // ⬇️ Increment guessed counter
        room.gussedUserCtr = (room.gussedUserCtr || 0) + 1;

        await room.save();

        io.to(data.roomName).emit('msg', {
          username: data.username,
          msg: 'Guessed it',
          gussedUserCtr: room.gussedUserCtr,
        });

        // ⬇️ Check if all others guessed
        if (room.gussedUserCtr >= room.players.length - 1) {
          io.to(data.roomName).emit('change-turn', room);
        }
      } else {
        io.to(data.roomName).emit('msg', {
          username: data.username,
          msg: data.msg,
          gussedUserCtr: room.gussedUserCtr || 0,
        });
      }
    } catch (err) {
      console.error(err);
    }
  });

  // CHANGE TURN
  socket.on('change-turn', async (name) => {
    try {
      let room = await Room.findOne({ name });
      if (!room) return;

      const idx = room.turnIndex;
      if (idx + 1 === room.players.length) {
        room.currentRound += 1;
      }

      if (room.currentRound <= room.maxRounds) {
        const newWord = getWord();
        room.word = newWord;
        room.turnIndex = (idx + 1) % room.players.length;
        room.turn = room.players[room.turnIndex];
        room.gussedUserCtr = 0;

        room = await room.save();
        io.to(name).emit('change-turn', room);
      } else {
        // TODO: emit leaderboard logic
        io.to(name).emit('show-leaderboard', room.players);
      }
    } catch (err) {
      console.error(err);
    }
  });

  socket.on('disconnect', () => {
    console.log('🔴 User disconnected:', socket.id);
    // optional: remove player from room, etc.
  });
});

// Start the server
server.listen(port, "0.0.0.0", () => {
  console.log(`🚀 Server running on http://localhost:${port}`);
});

const mongoose = require('mongoose');
const { playerSchema } = require('./Player');

const roomSchema = new mongoose.Schema({
  word: {
    type: String,
    default: '',
  },
  wordChoices: {
    type: [String],
    default: [],
  },
  isChoosingWord: {
    type: Boolean,
    default: false,
  },
  name: {
    required: true,
    type: String,
    unique: true,
    trim: true,
  },
  occupancy: {
    required: true,
    type: Number,
    default: 4,
  },
  maxRounds: {
    required: true,
    type: Number,
  },
  currentRound: {
    required: true,
    type: Number,
    default: 1,
  },
  players: [playerSchema],
  isJoin: {
    type: Boolean,
    default: true,
  },
  turn: playerSchema,
  turnIndex: {
    type: Number,
    default: 0,
  },
  isGameOver: {
    type: Boolean,
    default: false,
  },
});

const gameModel = mongoose.model('Room', roomSchema);
module.exports = gameModel;
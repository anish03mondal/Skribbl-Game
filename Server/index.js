const { Socket } = require('dgram');
const express = require('express');
var http = require('http');
var app = express();
const port = process.env.port || 3000;
//This line creates an HTTP server in Node.js using the http module, and uses an Express app (app) to handle requests.
var server = http.createServer(app);
const mongoose = require('mongoose');
const Room = require('./models/Room');
const getWord = require('./api/getWord');
//Loads the Socket.IO library and attaches it to your HTTP server.
var io = require('socket.io')(server);

//middleware
//express.json() parses that string and turns it into a JavaScript object:
app.use(express.json());

const DB = 'mongodb+srv://anish03mondal:Anish12345@cluster0.knr6sql.mongodb.net/'

mongoose.connect(DB).then(()=> {
    try
    {
        console.log('Connection successful');
    }
    catch(e)
    {
        console.log(e);
    }
    
})

io.on('connection', (socket) => {
    console.log('Connected');
    // create game callback
    socket.on('create-game', async({nickname, name, occupancy, maxRounds}) => {
        try {
            const existingRoom = await Room.findOne({name});
            if(existingRoom)
            {
                socket.emit('notCorrectGame', 'Room with that name already exists');
                return;
            }
            let room = new Room;
            let word = getWord();
            room.word = word;
            room.nickname = nickname;
            room.name = name;
            room.occupancy = occupancy;
            room.maxRounds = maxRounds;

            let player = {
                socketID: socket.id,
                nickname,
                isPartyLeader: true,
            }
            room.players.push(player);
            room = await room.save();
            socket.join(name);
            io.to(name).emit('updateRoom', room);
            
        } catch (err) {
            console.log(err);
            
        }
    })

    //join game call back
    socket.on('join-game', async ({nickname, name}) => {
        try{
            let room = await Room.findOne({name});
            if(!room)
            {
                socket.emit('notCorrectGame', 'Please enter a valid room name');
                return;
            }
            
            if(room.isJoin)
            {
                let player = {
                    socketID : socket.id,
                    nickname,
                }
                room.players.push(player);
                socket.join(name);

                if(room.players.length === room.occupancy)
                {
                    room.isJoin = false;
                }
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                io.to(name).emit('updateRoom', room);
            }
            else
            {
                socket.emit('notCorrectGame', 'The game is in progress, please try again later');
            }
        }
        catch(err)
        {
            console.log(err);
        }
    })

    //White board socket
    socket.on('paint', ({details, roomName}) => {
        io.to(roomName).emit('points', {details: details});
    })

    //Color socket
    socket.on('color-change', ({color, roomName}) => {
        io.to(roomName).emit('color-change', color);
    })

    //Stroke socket
    socket.on('stroke-width', ({value, roomName}) => {
        io.to(roomName).emit('stroke-width', value);
    })

    //Clear screen
    socket.on('clean-screen', (roomName) => {
        io.to(roomName).emit('clear-screen', '');
    })

    //message
    socket.on('msg', async(data) => {
        try {
            io.to(data.roomName).emit('msg', {
                username: data.username,
                msg: data.msg,
            })
        }
        catch(err)
        {
            console.log(err.toString());
        }
    })
})

server.listen(port, "0.0.0.0", () => {
    console.log("Server started and running on port " + port)
})

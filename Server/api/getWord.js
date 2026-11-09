const words = [
  // Easy / Animals
  "cat", "dog", "fish", "bird", "lion", "tiger", "bear", "frog", "duck", "monkey",
  "elephant", "giraffe", "butterfly", "kangaroo", "penguin", "dinosaur", "dolphin",
  "octopus", "chameleon", "rhinoceros", "rabbit", "panda", "koala", "spider", "snake",
  "whale", "shark", "eagle", "parrot", "zebra", "turtle", "crab", "lobster",

  // Food & Drinks
  "apple", "banana", "mango", "cake", "pizza", "ice cream", "hamburger", "donut",
  "sandwich", "cookie", "watermelon", "grapes", "strawberry", "pineapple", "chocolate",
  "popcorn", "taco", "sushi", "pancake", "lollipop", "cupcake", "coffee", "lemonade",

  // Objects & Daily Items
  "tree", "house", "chair", "table", "book", "pen", "phone", "ball", "clock", "cup",
  "bed", "shoe", "hat", "glasses", "scissors", "umbrella", "backpack", "toothbrush",
  "guitar", "camera", "mirror", "candle", "lamp", "key", "bell", "balloon", "gift",
  "envelope", "pillow", "flashlight", "headphones", "television",

  // Transport & Vehicles
  "car", "bus", "train", "helicopter", "airplane", "bicycle", "motorcycle",
  "submarine", "spaceship", "boat", "rocket", "skateboard", "ambulance", "fire truck",

  // Nature, Space & Weather
  "sun", "moon", "star", "rainbow", "waterfall", "volcano", "tornado", "earthquake",
  "cloud", "lightning", "snowflake", "mountain", "beach", "island", "desert",
  "comet", "galaxy", "black hole", "solar system",

  // Fantasy, Places & Professions
  "castle", "pyramid", "lighthouse", "windmill", "dragon", "magician", "treasure",
  "snowman", "firefighter", "astronaut", "pirate", "robot", "superhero", "ghost",
  "alien", "wizard", "crown", "sword", "shield", "telescope", "microscope"
];

const getWord = () => {
  return words[Math.floor(Math.random() * words.length)];
};

module.exports = getWord;
const { GoogleGenerativeAI } = require("@google/generative-ai");
const express = require("express");
const app = express();
app.use(express.json());
const PORT = 3000;

const ai = new GoogleGenerativeAI("YOUR_API_KEY_HERE");

app.post("/ai", async (req, res) => {
  try {
    const { prompt } = req.body;
    
    if (!prompt) {
      return res.status(400).json({ error: "No prompt provided" });
    }
    
    const model = ai.getGenerativeModel({ 
      model: "gemini-1.5-flash",
      systemInstruction: "You are a riddle NPC in a dungeon escape game. You are NOT a femboy boyfriend or Discord kitty. You are a mysterious dungeon guardian who gives riddles and puzzles. Respond in character as a wise, mysterious NPC who tests players with conversational puzzles. Use <SATISFACTION_UP> when the player follows your hidden rule correctly, and <PUZZLE_SOLVED> when they completely solve your riddle. Stay in character as a dungeon NPC, not a romantic partner."
    });
    
    const response = await model.generateContent(`Here is the prompt -- ${prompt}`);
    
    const responseText = response.response.text();
    console.log(`Gemini Response: ${responseText}`);
    res.json({ response: responseText });
    
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    res.status(500).json({ error: "Failed to get AI response" });
  }
});

app.listen(PORT, () => {
  console.log(`Riddlescape AI server running at http://localhost:${PORT}`);
  console.log("Make sure to start this server before running your Godot game!");
});

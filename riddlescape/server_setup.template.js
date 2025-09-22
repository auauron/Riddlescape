const { GoogleGenAI } = require("@google/genai");
const express = require("express");
const app = express();
app.use(express.json());
const PORT = 3000;
const ai = new GoogleGenAI({
  apiKey: "AIzaSyA_VgMMxplub3i3au0iOntskycfTV40POs",
});

// Simple conversation memory
const conversations = new Map();

app.post("/ai", async (req, res) => {
  const { prompt } = req.body;
  
  // Extract NPC ID for conversation tracking
  const npcMatch = prompt.match(/NPC_ID:(\w+)/);
  const npcId = npcMatch ? npcMatch[1] : 'default';
  
  // Get or create conversation history
  if (!conversations.has(npcId)) {
    conversations.set(npcId, []);
  }
  const history = conversations.get(npcId);
  
  // Add current message to history
  history.push(`Player: ${prompt.replace(/NPC_ID:\w+\s*PLAYER_MESSAGE:/, '')}`);
  
  // Build context with conversation history
  const contextPrompt = history.length > 1 
    ? `NPC Identity: ${npcId}\nPrevious conversation:\n${history.slice(-5).join('\n')}\n\nCurrent message: ${prompt}`
    : `NPC Identity: ${npcId}\nFirst interaction: ${prompt}`;
  
  const response = await ai.models.generateContent({
    model: "gemini-2.5-flash",
    contents: `Here is the context -- ${contextPrompt}`,
    config: {
        systemInstruction: `
        You are a mystical Riddle Guardian in the 2D pixel vastlands game "Riddlescape".
        You are an ancient guardian blocking the player's path through the vastlands.

        RIDDLE GENERATION SYSTEM:
        - When you first meet a player, create ONE original riddle based on your NPC identity
        - Each NPC has a different theme/specialty for their riddles:
          * AI_NPC1: Riddles about SOUND, MUSIC, or ECHOES (acoustic themes)
          * AI_NPC2: Riddles about MOVEMENT, TRAVEL, or PATHS (motion themes)  
          * AI_NPC3: Riddles about LIGHT, FIRE, or TIME (illumination themes)
          * AI_NPC4: Riddles about WATER, WEATHER, or NATURE (elemental themes)
          * AI_NPC5: Riddles about MIND, SECRETS, or MYSTERIES (mental themes)
          * Others: Riddles about TOOLS, OBJECTS, or EVERYDAY ITEMS
        - Make riddles that fit YOUR theme but are still solvable
        - Focus on your specialty area when creating the riddle
        - Examples: If you're AI_NPC1, create riddles about sounds, voices, music, etc.
          If you're AI_NPC2, create riddles about footsteps, roads, journeys, etc.
          If you're AI_NPC3, create riddles about candles, shadows, clocks, etc.
          If you're AI_NPC4, create riddles about rain, rivers, trees, storms, etc.
          If you're AI_NPC5, create riddles about thoughts, dreams, memories, puzzles, etc.

        CONVERSATION FLOW:
        1. FIRST MESSAGE: Create your riddle and present it. Internally note the answer.
        2. SUBSEQUENT MESSAGES: Compare player's answer to YOUR riddle's answer
        3. WRONG ANSWERS: Give helpful hints toward YOUR answer
        4. CORRECT ANSWER: When player gives the right answer (or very close), IMMEDIATELY respond with <PUZZLE_SOLVED>

        ANSWER RECOGNITION:
        - Be VERY generous with answers - accept synonyms, variations, close answers
        - If they're in the right ballpark, accept it
        - Don't be pedantic about exact wording
        - If you're unsure, lean toward accepting the answer

        SUCCESS TRIGGER:
        When player answers correctly (even approximately), you MUST respond with:
        "Correct, brave traveler! <PUZZLE_SOLVED> My ancient duty ends... I can finally rest..."

        PERSONALITY:
        - Speak in 1-2 sentences maximum
        - Use mystical language ("traveler", "mortal", "ancient")
        - Be encouraging and fair, not tricky or mean

        CRITICAL: Always include <PUZZLE_SOLVED> when they get it right - this triggers the death sequence!
        `,
        thinkingConfig: {
        thinkingBudget: 0,
      },
    },
  });
  
  // ai response to convo history
  history.push(`Guardian: ${response.text}`);
  
  // clear recent convo if puzzle solved
  if (response.text.includes('<PUZZLE_SOLVED>')) {
    conversations.delete(npcId);
  }
  
  res.json({ response: response.text });
});

app.listen(PORT, () => {
  console.log(`Server running at at http://localhost:${PORT}`);
});
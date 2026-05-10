const express = require('express');
const cors = require('cors');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const FormData = require('form-data');

const app = express();
app.use(cors());
app.use(express.json());

// Set up storage for uploaded videos
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = './uploads';
        if (!fs.existsSync(dir)){
            fs.mkdirSync(dir);
        }
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

// Database mockup
const DB_FILE = './db.json';
if (!fs.existsSync(DB_FILE)) {
    fs.writeFileSync(DB_FILE, JSON.stringify({ reports: [] }));
}

const AGENT_URL = 'http://localhost:5000/analyze';

// 1. Upload Video and Trigger Agent
app.post('/api/analyze', upload.single('video'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No video file provided' });
        }

        const filePath = req.file.path;
        
        // Prepare file to send to Agent Engine
        const formData = new FormData();
        formData.append('video', fs.createReadStream(filePath));

        // Call Python Agent Engine
        const agentResponse = await axios.post(AGENT_URL, formData, {
            headers: {
                ...formData.getHeaders()
            }
        });

        const reportData = agentResponse.data;
        
        // Create full incident report
        const incidentReport = {
            id: 'REP-' + Date.now(),
            timestamp: new Date().toISOString(),
            filename: req.file.originalname,
            ...reportData,
            status: reportData.threat_severity === 'High' || reportData.threat_severity === 'Critical' ? 'Escalated' : 'Logged'
        };

        // Save to Mock DB
        const db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
        db.reports.push(incidentReport);
        fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));

        // Cleanup local file after processing
        fs.unlinkSync(filePath);

        res.json(incidentReport);

    } catch (error) {
        console.error("Error during analysis:", error.message);
        res.status(500).json({ error: 'Failed to process video' });
    }
});

// 2. Fetch all reports (For Dashboard)
app.get('/api/reports', (req, res) => {
    try {
        const db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
        // Return descending
        res.json(db.reports.reverse());
    } catch(err) {
        res.status(500).json({ error: 'Failed to fetch reports' });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Backend API running on port ${PORT}`);
});

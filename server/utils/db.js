const mysql = require('mysql2');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  namedPlaceholders: true,
}).promise();

// Function to create 'todos' table if it doesn't exist
async function createTodosTableIfNotExists() {
  try {
    await pool.execute(`
      CREATE TABLE IF NOT EXISTS todos (
        id VARCHAR(36) PRIMARY KEY,
        todo VARCHAR(50) NOT NULL
      )
    `);
    console.log("'todos' table checked/created.");
  } catch (err) {
    console.error(' Error creating todos table:', err);
  }
}

createTodosTableIfNotExists();

module.exports = { pool };

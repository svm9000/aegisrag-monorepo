import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'

const container = document.getElementById('root')

// Defensively handle missing DOM nodes in complex or containerized deployment spaces
if (!container) {
  throw new Error("Target root mounting container not found. Check index.html parameters.")
}

const root = createRoot(container)

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)

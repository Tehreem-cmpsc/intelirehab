import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import ErrorBoundary from './presentation/ErrorBoundary.jsx'

// Apply the saved theme before React renders, so the first screen (and the loader) is not a light flash in dark mode.
try {
  document.documentElement.setAttribute('data-theme', localStorage.getItem('theme') === 'dark' ? 'dark' : 'light')
} catch {
  // storage blocked: the app sets the theme once it mounts
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>,
)

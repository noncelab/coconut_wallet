//! Session management for device access.

use std::collections::HashMap;
use std::sync::{Arc, RwLock};

/// Session manager for tracking device sessions
#[derive(Debug, Default)]
pub struct SessionManager {
    /// Map of device path to session ID
    sessions: Arc<RwLock<HashMap<String, String>>>,
    /// Counter for generating session IDs
    counter: Arc<RwLock<u64>>,
}

impl SessionManager {
    /// Create a new session manager
    pub fn new() -> Self {
        Self::default()
    }

    /// Acquire a session for a device
    pub fn acquire(&self, path: &str, previous: Option<&str>) -> Result<String, &'static str> {
        let mut sessions = self.sessions.write().map_err(|_| "Lock poisoned")?;

        // Check if device already has a session
        if let Some(current) = sessions.get(path) {
            if let Some(prev) = previous {
                if current != prev {
                    return Err("Wrong previous session");
                }
            } else {
                return Err("Session already acquired");
            }
        }

        // Generate new session ID
        let mut counter = self.counter.write().map_err(|_| "Lock poisoned")?;
        *counter += 1;
        let session_id = format!("{}", *counter);

        sessions.insert(path.to_string(), session_id.clone());
        Ok(session_id)
    }

    /// Release a session
    pub fn release(&self, session: &str) -> Result<(), &'static str> {
        let mut sessions = self.sessions.write().map_err(|_| "Lock poisoned")?;

        // Find and remove the session
        let path = sessions
            .iter()
            .find(|(_, s)| *s == session)
            .map(|(p, _)| p.clone());

        if let Some(path) = path {
            sessions.remove(&path);
            Ok(())
        } else {
            Err("Session not found")
        }
    }

    /// Get path for a session
    pub fn get_path(&self, session: &str) -> Option<String> {
        let sessions = self.sessions.read().ok()?;
        sessions
            .iter()
            .find(|(_, s)| *s == session)
            .map(|(p, _)| p.clone())
    }

    /// Get session for a path
    pub fn get_session(&self, path: &str) -> Option<String> {
        let sessions = self.sessions.read().ok()?;
        sessions.get(path).cloned()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_acquire_release() {
        let manager = SessionManager::new();

        let session = manager.acquire("device1", None).unwrap();
        assert!(!session.is_empty());

        // Can't acquire again without previous
        assert!(manager.acquire("device1", None).is_err());

        // Can acquire with correct previous
        let session2 = manager.acquire("device1", Some(&session)).unwrap();
        assert_ne!(session, session2);

        // Release
        manager.release(&session2).unwrap();

        // Can acquire again
        let session3 = manager.acquire("device1", None).unwrap();
        assert!(!session3.is_empty());
    }
}

import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { Box } from '@mui/material';

// Page imports
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Register from './pages/Register';
import ExerciseLibrary from './pages/ExerciseLibrary';
import WorkoutTracker from './pages/WorkoutTracker';
import NutritionTracker from './pages/NutritionTracker';
import ProgressReports from './pages/ProgressReports';
import Profile from './pages/Profile';
import Settings from './pages/Settings';

// Component imports
import Navbar from './components/Navbar';
import PrivateRoute from './components/PrivateRoute';
import { useAuth } from './contexts/AuthContext';

function App() {
  const { currentUser } = useAuth();

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
      {currentUser && <Navbar />}
      <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route 
            path="/" 
            element={
              <PrivateRoute>
                <Dashboard />
              </PrivateRoute>
            } 
          />
          <Route 
            path="/exercises" 
            element={
              <PrivateRoute>
                <ExerciseLibrary />
              </PrivateRoute>
            } 
          />
          <Route 
            path="/workouts" 
            element={
              <PrivateRoute>
                <WorkoutTracker />
              </PrivateRoute>
            } 
          />
          <Route 
            path="/nutrition" 
            element={
              <PrivateRoute>
                <NutritionTracker />
              </PrivateRoute>
            } 
          />
          <Route 
            path="/progress" 
            element={
              <PrivateRoute>
                <ProgressReports />
              </PrivateRoute>
            } 
          />
          <Route 
            path="/profile" 
            element={
              <PrivateRoute>
                <Profile />
              </PrivateRoute>
            } 
          />
          <Route 
            path="/settings" 
            element={
              <PrivateRoute>
                <Settings />
              </PrivateRoute>
            } 
          />
        </Routes>
      </Box>
    </Box>
  );
}

export default App;
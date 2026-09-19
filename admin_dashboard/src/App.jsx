import { BrowserRouter, Routes, Route } from 'react-router-dom';
import ProtectedRoute from './routes/ProtectedRoute';
import AppShell from './components/AppShell';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import CaseList from './pages/Cases/CaseList';
import CaseDetail from './pages/Cases/CaseDetail';
import QuestionBuilder from './pages/QuestionBuilder';
import Doctors from './pages/Doctors';
import UserList from './pages/Users/UserList';
import UserDetail from './pages/Users/UserDetail';
import Tickets from './pages/Tickets';
import VideoCalls from './pages/VideoCalls';
import Notifications from './pages/Notifications';
import Settings from './pages/Settings';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <ProtectedRoute>
              <AppShell />
            </ProtectedRoute>
          }
        >
          <Route path="/" element={<Dashboard />} />
          <Route path="/cases" element={<CaseList />} />
          <Route path="/cases/:id" element={<CaseDetail />} />
          <Route path="/question-builder" element={<QuestionBuilder />} />
          <Route path="/doctors" element={<Doctors />} />
          <Route path="/users" element={<UserList />} />
          <Route path="/users/:id" element={<UserDetail />} />
          <Route path="/tickets" element={<Tickets />} />
          <Route path="/video-calls" element={<VideoCalls />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

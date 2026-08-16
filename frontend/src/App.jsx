import { Route, Routes } from 'react-router-dom';
import Navbar from './components/Navbar';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import UserDetail from './pages/UserDetail';

export default function App() {
  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-1">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/login" element={<Login />} />
          <Route path="/user/:id" element={<UserDetail />} />
          <Route
            path="*"
            element={
              <div className="max-w-2xl mx-auto py-20 px-4 text-center">
                <h1 className="text-3xl font-bold text-slate-900">404</h1>
                <p className="text-slate-500 mt-2">Pagina no encontrada.</p>
              </div>
            }
          />
        </Routes>
      </main>
      <footer className="border-t border-slate-200 bg-white">
        <div className="max-w-7xl mx-auto px-4 py-4 text-xs text-slate-500 flex flex-col sm:flex-row justify-between gap-1">
          <span>Clash Dashboard · datos leídos de la base.</span>
          <span>Hecho con React + Vite + Tailwind.</span>
        </div>
      </footer>
    </div>
  );
}

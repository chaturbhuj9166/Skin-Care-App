import { io } from 'socket.io-client';
import { useEffect } from 'react';
import { useAuthStore } from '../store/authStore';

let socket = null;

export function getSocket() {
  const token = useAuthStore.getState().token;
  if (!token) return null;

  if (!socket) {
    socket = io(import.meta.env.VITE_API_URL, { auth: { token }, autoConnect: false });
  }
  socket.auth = { token };
  if (!socket.connected) socket.connect();
  return socket;
}

export function disconnectSocket() {
  if (socket) {
    socket.disconnect();
    socket = null;
  }
}

// Subscribes to one or more socket events for the lifetime of the component.
export function useSocketEvent(events, handler) {
  useEffect(() => {
    const s = getSocket();
    if (!s) return undefined;

    const list = Array.isArray(events) ? events : [events];
    list.forEach((event) => s.on(event, handler));
    return () => list.forEach((event) => s.off(event, handler));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [Array.isArray(events) ? events.join(',') : events]);
}

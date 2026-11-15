export type ConnectionState = "disconnected" | "connecting" | "connected";
// Only instantiate after backend integration; no simulated socket connection.
export function connectRideSocket(
  url: string,
  onEvent: (data: unknown) => void,
  onState: (state: ConnectionState) => void,
) {
  let socket: WebSocket | undefined;
  let timer: ReturnType<typeof setTimeout>;
  let stopped = false;
  let attempts = 0;
  const connect = () => {
    onState("connecting");
    socket = new WebSocket(url);
    socket.onopen = () => {
      attempts = 0;
      onState("connected");
    };
    socket.onmessage = (event) => {
      try {
        onEvent(JSON.parse(event.data));
      } catch {
        /* Ignore malformed frames. */
      }
    };
    socket.onclose = () => {
      onState("disconnected");
      if (!stopped)
        timer = setTimeout(connect, Math.min(1000 * 2 ** attempts++, 30000));
    };
    socket.onerror = () => socket?.close();
  };
  connect();
  return () => {
    stopped = true;
    clearTimeout(timer);
    socket?.close();
  };
}

import { Injectable, signal } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { GameState, JoinResponse } from './game.models';

@Injectable({ providedIn: 'root' })
export class GameService {
  readonly game = signal<GameState | null>(null);
  readonly player = signal('');
  readonly symbol = signal('');
  readonly status = signal('Noch nicht verbunden.');
  private socket?: WebSocket;

  constructor(private readonly http: HttpClient) {
    this.connectSocket();
  }

  join(name: string): void {
    const player = name.trim() || 'Demo-Spieler';
    this.http.post<JoinResponse>(`/api/game/join?player_name=${encodeURIComponent(player)}`, {}, {
      headers: this.headers(player)
    }).subscribe({
      next: response => {
        this.player.set(response.player);
        this.symbol.set(response.symbol);
        this.game.set(response.game);
        this.status.set(`Verbunden als ${player} · ${response.symbol || 'Zuschauer'}`);
      },
      error: error => this.status.set(this.errorMessage(error))
    });
  }

  move(position: number): void {
    this.http.post<GameState>('/api/game/move', { position }, {
      headers: this.headers(this.player())
    }).subscribe({
      next: game => this.game.set(game),
      error: error => this.status.set(this.errorMessage(error))
    });
  }

  reset(): void {
    this.http.post<GameState>('/api/game/reset', {}, {
      headers: this.headers(this.player())
    }).subscribe({
      next: game => this.game.set(game),
      error: error => this.status.set(this.errorMessage(error))
    });
  }

  private connectSocket(): void {
    const protocol = location.protocol === 'https:' ? 'wss' : 'ws';
    this.socket = new WebSocket(`${protocol}://${location.host}/ws/game`);
    this.socket.onopen = () => this.status.set('Live verbunden · WebSocket aktiv');
    this.socket.onmessage = event => {
      const message = JSON.parse(event.data) as { data: GameState };
      this.game.set(message.data);
    };
    this.socket.onclose = () => this.status.set('Live-Verbindung getrennt');
  }

  private headers(player: string): HttpHeaders {
    return new HttpHeaders({ 'Content-Type': 'application/json', 'X-Player': player });
  }

  private errorMessage(error: { error?: { detail?: string } }): string {
    return error.error?.detail || 'Die Anfrage wurde abgelehnt.';
  }
}

export interface GameState {
  board: Array<'X' | 'O' | null>;
  players: Record<string, string>;
  turn: 'X' | 'O';
  status: 'waiting' | 'playing' | 'finished';
  winner: 'X' | 'O' | 'draw' | '';
  version: number;
}

export interface JoinResponse {
  player: string;
  symbol: string;
  game: GameState;
}

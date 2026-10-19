import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { GameService } from './game.service';
import { GameState } from './game.models';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  readonly gameService = inject(GameService);
  playerName = '';

  get game(): GameState | null { return this.gameService.game(); }

  join(): void { this.gameService.join(this.playerName); }
  move(position: number): void { this.gameService.move(position); }
  reset(): void { this.gameService.reset(); }

  cellDisabled(value: string | null): boolean {
    const game = this.game;
    return Boolean(value) || game?.status !== 'playing' || game.turn !== this.gameService.symbol();
  }

  gameStatus(game: GameState): string {
    if (game.status === 'finished') return game.winner === 'draw' ? 'Unentschieden' : `${game.winner} gewinnt`;
    return game.status === 'waiting' ? 'Wartet auf Spieler' : `Am Zug: ${game.turn}`;
  }

  winnerName(game: GameState): string {
    return game.winner === 'draw' ? 'Unentschieden' : `${game.players[game.winner] || 'Unbekannter Spieler'} gewinnt`;
  }
}

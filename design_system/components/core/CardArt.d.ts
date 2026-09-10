import * as React from "react";

/**
 * Arte da carta na proporção física (.72). Enquanto não há imagem real,
 * renderiza o placeholder listrado — nunca desenhe uma carta.
 * @startingPoint section="Core" subtitle="Arte de carta, cheia e vazia" viewport="700x160"
 */
export interface CardArtProps {
  /** URL de imagem ou valor CSS de background. */
  src?: string;
  /** Largura em px; a altura sai da proporção .72. */
  width?: number;
  /** Slot não registrado: listrado + borda tracejada. */
  empty?: boolean;
  label?: string;
  radius?: string;
  style?: React.CSSProperties;
}
export function CardArt(props: CardArtProps): JSX.Element;

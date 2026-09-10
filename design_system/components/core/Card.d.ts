import * as React from "react";

/**
 * Container de conteúdo. `hero` é o único uso de roxo cheio em superfície —
 * no máximo um por tela (valor da coleção, coleção em andamento).
 * @startingPoint section="Core" subtitle="Superfícies: branca, tingida e hero roxa" viewport="700x200"
 */
export interface CardProps {
  tone?: "surface" | "tinted" | "hero";
  padding?: number | string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Card(props: CardProps): JSX.Element;

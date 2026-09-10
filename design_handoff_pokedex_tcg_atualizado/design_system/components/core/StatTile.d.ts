import * as React from "react";

/** Célula de estatística. Usada em grade 2x2 (detalhe da carta, perfil). */
export interface StatTileProps {
  label?: React.ReactNode;
  value?: React.ReactNode;
  style?: React.CSSProperties;
}
export function StatTile(props: StatTileProps): JSX.Element;

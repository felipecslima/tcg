import * as React from "react";

/** Filtro de seleção única ou múltipla, em faixa horizontal rolável. */
export interface ChipProps {
  selected?: boolean;
  onClick?: () => void;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Chip(props: ChipProps): JSX.Element;

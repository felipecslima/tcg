import * as React from "react";

/** Escolha única em lista (para qual coleção guardar, qual perfil usar). */
export interface RadioRowProps {
  selected?: boolean;
  label?: React.ReactNode;
  /** Contagem ou dica à direita. */
  trailing?: React.ReactNode;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export function RadioRow(props: RadioRowProps): JSX.Element;

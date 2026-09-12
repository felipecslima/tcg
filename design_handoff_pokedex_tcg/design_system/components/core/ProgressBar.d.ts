import * as React from "react";

/** Barra de progresso de coleção. Sempre acompanhada do número em texto. */
export interface ProgressBarProps {
  /** 0–100. */
  value?: number;
  height?: number;
  onDark?: boolean;
  style?: React.CSSProperties;
}
export function ProgressBar(props: ProgressBarProps): JSX.Element;

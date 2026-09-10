import * as React from "react";

/** Rótulo de seção em mono maiúsculo. Antecede grupos de conteúdo. */
export interface SectionLabelProps {
  /** Sobre superfície roxa/hero. */
  onDark?: boolean;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function SectionLabel(props: SectionLabelProps): JSX.Element;

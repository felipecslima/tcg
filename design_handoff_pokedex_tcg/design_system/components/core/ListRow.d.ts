import * as React from "react";

/**
 * Linha de carta ou coleção: arte, título, meta e um valor à direita.
 * @startingPoint section="Core" subtitle="Linha de carta com arte, meta e valor" viewport="700x180"
 */
export interface ListRowProps {
  /** Valor CSS de background da arte; omita para linha sem arte. */
  art?: string;
  title?: React.ReactNode;
  meta?: React.ReactNode;
  /** Valor principal à direita (preço, contagem). */
  trailing?: React.ReactNode;
  /** Segunda linha à direita — colora com --ds-positive / --ds-negative. */
  trailingSub?: React.ReactNode;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export function ListRow(props: ListRowProps): JSX.Element;

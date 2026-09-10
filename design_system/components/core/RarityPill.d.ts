import * as React from "react";

/** Raridade da carta. O dourado é exclusivo de raridade, HP e valor — nunca decorativo. */
export interface RarityPillProps {
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function RarityPill(props: RarityPillProps): JSX.Element;

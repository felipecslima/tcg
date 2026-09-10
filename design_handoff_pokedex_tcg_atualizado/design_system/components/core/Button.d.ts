import * as React from "react";

/**
 * Botão de ação. Primário para a ação principal da tela (um por tela),
 * dashed para escapes ("adicionar manualmente", "não sei a coleção").
 * @startingPoint section="Core" subtitle="Ações primárias, secundárias e de escape" viewport="700x160"
 */
export interface ButtonProps {
  variant?: "primary" | "secondary" | "ghost" | "dashed";
  size?: "sm" | "md" | "lg";
  /** Ocupa a largura total do container. Padrão das ações de rodapé. */
  full?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Button(props: ButtonProps): JSX.Element;

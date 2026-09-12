import React from "react";

const V = {
  primary: { background: "var(--ds-action)", color: "#fff", border: "1px solid transparent", boxShadow: "var(--ds-shadow-action)" },
  secondary: { background: "var(--ds-surface)", color: "var(--ds-text-primary)", border: "1px solid var(--ds-border-strong)", boxShadow: "none" },
  ghost: { background: "transparent", color: "var(--ds-text-secondary)", border: "1px solid transparent", boxShadow: "none" },
  dashed: { background: "var(--ds-tint-soft)", color: "var(--ds-action-strong)", border: "1px dashed var(--ds-border-strong)", boxShadow: "none" }
};

const S = {
  sm: { padding: "9px 14px", font: "500 13px/1 var(--ds-font-body)", borderRadius: "var(--ds-radius-md)" },
  md: { padding: "15px", font: "var(--ds-type-button)", borderRadius: "var(--ds-radius-lg)" },
  lg: { padding: "17px", font: "700 16px/1 var(--ds-font-display)", borderRadius: "17px" }
};

export function Button({ variant = "primary", size = "md", full = false, disabled = false, onClick, children, style }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      style={{
        ...V[variant], ...S[size],
        width: full ? "100%" : undefined,
        cursor: disabled ? "not-allowed" : "pointer",
        opacity: disabled ? .45 : 1,
        display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
        ...style
      }}
    >{children}</button>
  );
}

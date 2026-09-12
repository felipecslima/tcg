import React from "react";
import { SectionLabel } from "./SectionLabel.jsx";

export function StatTile({ label, value, style }) {
  return (
    <div style={{
      padding: 16, borderRadius: "var(--ds-radius-lg)",
      background: "var(--ds-surface)", border: "1px solid var(--ds-border)", ...style
    }}>
      <SectionLabel style={{ fontSize: 10, letterSpacing: ".1em" }}>{label}</SectionLabel>
      <div style={{ font: "600 17px/1.2 var(--ds-font-display)", color: "var(--ds-text-primary)", marginTop: 8 }}>{value}</div>
    </div>
  );
}

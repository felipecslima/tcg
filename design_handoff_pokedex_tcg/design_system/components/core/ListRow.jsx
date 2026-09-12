import React from "react";
import { CardArt } from "./CardArt.jsx";

export function ListRow({ art, title, meta, trailing, trailingSub, onClick, style }) {
  return (
    <button onClick={onClick} style={{
      display: "flex", alignItems: "center", gap: 14, width: "100%", textAlign: "left",
      padding: 11, borderRadius: "var(--ds-radius-lg)",
      border: "1px solid var(--ds-border)", background: "var(--ds-surface)",
      cursor: onClick ? "pointer" : "default", ...style
    }}>
      {art !== undefined && <CardArt width={46} src={art} />}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: "var(--ds-type-item)", color: "var(--ds-text-primary)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{title}</div>
        {meta && <div style={{ font: "var(--ds-type-caption)", color: "var(--ds-text-secondary)", marginTop: 4 }}>{meta}</div>}
      </div>
      {(trailing || trailingSub) && (
        <div style={{ textAlign: "right", flex: "none" }}>
          {trailing && <div style={{ font: "var(--ds-type-num)", color: "var(--ds-text-primary)" }}>{trailing}</div>}
          {trailingSub && <div style={{ font: "500 11px/1 var(--ds-font-mono)", marginTop: 5 }}>{trailingSub}</div>}
        </div>
      )}
    </button>
  );
}

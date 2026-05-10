"use client";
import { useEffect, useState } from "react";
import Link from "next/link";

interface BackupInfo {
  success: boolean;
  latestBackup: string;
  lastDate: string;
  totalBackups: number;
  backups: string[];
}

export default function ConfigPage() {
  const [backup, setBackup] = useState<BackupInfo | null>(null);
  const [backupLoading, setBackupLoading] = useState(false);
  const [backupMsg, setBackupMsg] = useState("");
  const [rebootLoading, setRebootLoading] = useState(false);
  const [rebootMsg, setRebootMsg] = useState("");
  const [updateLoading, setUpdateLoading] = useState(false);
  const [updateMsg, setUpdateMsg] = useState("");
  const [version, setVersion] = useState("");

  useEffect(() => {
    fetch("/api/backup").then(r => r.json()).then(setBackup);
    fetch("/api/openclaw-version").then(r => r.json()).then(d => setVersion(d.version));
  }, []);

  const triggerBackup = async () => {
    setBackupLoading(true);
    setBackupMsg("");
    try {
      const res = await fetch("/api/backup", { method: "POST" });
      const data = await res.json();
      if (data.success) {
        setBackupMsg("success");
        const res2 = await fetch("/api/backup");
        setBackup(await res2.json());
      } else {
        setBackupMsg("error: " + data.error);
      }
    } catch (e) {
      setBackupMsg("error: " + String(e));
    }
    setBackupLoading(false);
  };

  const triggerUpdate = async () => {
    if (!confirm("Openclaw auf neueste Version updaten?")) return;
    setUpdateLoading(true);
    setUpdateMsg("");
    try {
      const res = await fetch("/api/update-openclaw", { method: "POST" });
      const data = await res.json();
      setUpdateMsg(data.success ? "success" : "error: " + data.error);
      if (data.success) {
        const v = await fetch("/api/openclaw-version").then(r => r.json());
        setVersion(v.version);
      }
    } catch (e) {
      setUpdateMsg("error: " + String(e));
    }
    setUpdateLoading(false);
  };

  const triggerReboot = async () => {
    if (!confirm("Openclaw wirklich neu starten?")) return;
    setRebootLoading(true);
    setRebootMsg("");
    try {
      const res = await fetch("/api/restart", { method: "POST" });
      const data = await res.json();
      setRebootMsg(data.success ? "success" : "error: " + data.error);
    } catch (e) {
      setRebootMsg("error: " + String(e));
    }
    setRebootLoading(false);
  };

  return (
    <div style={{padding:"2rem",fontFamily:"system-ui",color:"#e5e5e5",maxWidth:800}}>
      <h1 style={{margin:"0 0 2rem",color:"#60a5fa"}}>⚙️ Konfiguration</h1>

      {/* Backup Section */}
      <div style={{background:"#1a1a1a",borderRadius:8,padding:"1.5rem",marginBottom:"1.5rem",border:"1px solid #2a2a2a"}}>
        <h2 style={{margin:"0 0 1rem",fontSize:16,color:"#ccc"}}>💾 GitHub Backup</h2>

        {backup ? (
          <div style={{marginBottom:"1rem"}}>
            <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:8}}>
              <span style={{fontSize:20}}>✅</span>
              <div>
                <div style={{fontSize:14,color:"#e5e5e5",fontWeight:"bold"}}>{backup.latestBackup}</div>
                <div style={{fontSize:12,color:"#888"}}>{backup.lastDate}</div>
              </div>
            </div>
            <div style={{fontSize:13,color:"#888"}}>
              {backup.totalBackups} Backups im Repo (letzte 7 Tage):
            </div>
            <div style={{display:"flex",flexWrap:"wrap",gap:4,marginTop:6}}>
              {backup.backups.map(b => {
                const match = b.match(/backup_(\d{4})(\d{2})(\d{2})/);
                const label = match ? `${match[1]}-${match[2]}-${match[3]}` : b;
                return (
                  <span key={b} style={{background:"#0e4429",color:"#4ade80",borderRadius:4,padding:"2px 8px",fontSize:11}}>
                    {label}
                  </span>
                );
              })}
            </div>
          </div>
        ) : (
          <p style={{color:"#888",fontSize:13}}>Lade Backup-Info...</p>
        )}

        {backupMsg === "success" && (
          <div style={{background:"#0e4429",border:"1px solid #4ade80",borderRadius:6,padding:"10px 14px",marginBottom:"1rem",fontSize:13,color:"#4ade80"}}>
            ✅ Backup erfolgreich auf GitHub erstellt!
          </div>
        )}
        {backupMsg.startsWith("error") && (
          <div style={{background:"#2d0000",border:"1px solid #f87171",borderRadius:6,padding:"10px 14px",marginBottom:"1rem",fontSize:13,color:"#f87171"}}>
            ❌ {backupMsg}
          </div>
        )}

        <button
          onClick={triggerBackup}
          disabled={backupLoading}
          style={{
            background: backupLoading ? "#2a2a2a" : "#2563eb",
            color:"#fff",border:"none",borderRadius:6,
            padding:"10px 20px",fontSize:14,cursor:backupLoading?"not-allowed":"pointer",
            opacity: backupLoading ? 0.7 : 1
          }}
        >
          {backupLoading ? "⏳ Backup läuft..." : "💾 Backup jetzt erstellen"}
        </button>
      </div>

      {/* Update Section */}
      <div style={{background:"#1a1a1a",borderRadius:8,padding:"1.5rem",marginBottom:"1.5rem",border:"1px solid #2a2a2a"}}>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"0.5rem"}}>
          <h2 style={{margin:0,fontSize:16,color:"#ccc"}}>🚀 Openclaw Update</h2>
          {version && <span style={{background:"#1e3a5f",color:"#60a5fa",borderRadius:4,padding:"3px 10px",fontSize:12,fontFamily:"monospace"}}>{version}</span>}
        </div>
        <p style={{fontSize:13,color:"#888",margin:"0 0 1rem"}}>
          Lädt die neueste Openclaw Version und startet den Container neu.
        </p>
        {updateMsg === "success" && (
          <div style={{background:"#0e4429",border:"1px solid #4ade80",borderRadius:6,padding:"10px 14px",marginBottom:"1rem",fontSize:13,color:"#4ade80"}}>
            ✅ Openclaw wurde erfolgreich aktualisiert!
          </div>
        )}
        {updateMsg.startsWith("error") && (
          <div style={{background:"#2d0000",border:"1px solid #f87171",borderRadius:6,padding:"10px 14px",marginBottom:"1rem",fontSize:13,color:"#f87171"}}>
            ❌ {updateMsg}
          </div>
        )}
        <button
          onClick={triggerUpdate}
          disabled={updateLoading}
          style={{
            background: updateLoading ? "#2a2a2a" : "#065f46",
            color:"#fff",border:"none",borderRadius:6,
            padding:"10px 20px",fontSize:14,cursor:updateLoading?"not-allowed":"pointer",
            opacity: updateLoading ? 0.7 : 1
          }}
        >
          {updateLoading ? "⏳ Update läuft..." : "🚀 Openclaw updaten"}
        </button>
      </div>

      {/* Reboot Section */}
      <div style={{background:"#1a1a1a",borderRadius:8,padding:"1.5rem",border:"1px solid #2a2a2a"}}>
        <h2 style={{margin:"0 0 0.5rem",fontSize:16,color:"#ccc"}}>🔄 Openclaw Neustart</h2>
        <p style={{fontSize:13,color:"#888",margin:"0 0 1rem"}}>
          Startet den Openclaw Container neu. Kurze Unterbrechung von ~30 Sekunden.
        </p>

        {rebootMsg === "success" && (
          <div style={{background:"#0e4429",border:"1px solid #4ade80",borderRadius:6,padding:"10px 14px",marginBottom:"1rem",fontSize:13,color:"#4ade80"}}>
            ✅ Openclaw wird neu gestartet...
          </div>
        )}
        {rebootMsg.startsWith("error") && (
          <div style={{background:"#2d0000",border:"1px solid #f87171",borderRadius:6,padding:"10px 14px",marginBottom:"1rem",fontSize:13,color:"#f87171"}}>
            ❌ {rebootMsg}
          </div>
        )}

        <button
          onClick={triggerReboot}
          disabled={rebootLoading}
          style={{
            background: rebootLoading ? "#2a2a2a" : "#7c3aed",
            color:"#fff",border:"none",borderRadius:6,
            padding:"10px 20px",fontSize:14,cursor:rebootLoading?"not-allowed":"pointer",
            opacity: rebootLoading ? 0.7 : 1
          }}
        >
          {rebootLoading ? "⏳ Neustart..." : "🔄 Openclaw neu starten"}
        </button>
      </div>
    </div>
  );
}

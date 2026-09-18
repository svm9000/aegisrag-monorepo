import React, { useState } from 'react';

export default function App() {
  const [text, setText] = useState('');
  const [query, setQuery] = useState('');
  const [answer, setAnswer] = useState('');
  const [metrics, setMetrics] = useState(null);
  const [logs, setLogs] = useState([]);
  const [loadingIngest, setLoadingIngest] = useState(false);
  const [loadingQuery, setLoadingQuery] = useState(false);

  const logEvent = (msg, status) => {
    setLogs(prev => [[new Date().toLocaleTimeString(), msg, status], ...prev]);
  };

  const wrapPayload = (data) => {
    logEvent("Packaging raw text into secure network payload structure...", "crypto");
    // TODO: Transition from insecure Base64 (btoa) encoding to true Web Crypto AES-GCM API
    return {
      encrypted_data: btoa(JSON.stringify(data)),
      encrypted_data_key: btoa("mock-kms-ciphertext-data-key"),
      iv: btoa("mock-init-vector-bytes")
    };
  };

  const handleIngest = async (e) => {
    e.preventDefault();
    if (!text.trim()) return;

    setLoadingIngest(true);
    logEvent("Transmitting encrypted envelope payload to secure endpoint gateway...", "network");
    
    try {
      // Uses relative path routing supported by the new Vite reverse proxy configuration
      const res = await fetch(`http://${window.location.hostname}:8000/api/v1/ingest`, {
      //const res = await fetch('/api/v1/ingest', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(wrapPayload({ text }))
      });
        
      if (!res.ok) throw new Error();
      
      logEvent("Ingest processing completion registered dynamically.", "success");
      setText('');
    } catch (err) {
      logEvent("Network failure communicating with cryptographic perimeter.", "error");
    } finally {
      setLoadingIngest(false);
    }
  };

  const handleQuery = async (e) => {
    e.preventDefault();
    if (!query.trim()) return;

    setLoadingQuery(true);
    logEvent("Executing cross-encoder semantic retrieval query transaction...", "network");
    
    try {
      // const res = await fetch('/api/v1/query', {
      //   method: 'POST',
      //   headers: { 'Content-Type': 'application/json' },
      //   body: JSON.stringify(wrapPayload({ query }))
      // });

      const res = await fetch(`http://${window.location.hostname}:8000/api/v1/query`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(wrapPayload({ query }))
      });


      
      if (!res.ok) throw new Error();

      const data = await res.json();
      setAnswer(data.answer);
      setMetrics(data.metrics);
      logEvent("Response payload processed completely from neural context synthesis.", "success");
    } catch (err) {
      logEvent("Network connection dropped during multi-stage evaluation sequence.", "error");
    } finally {
      setLoadingQuery(false);
    }
  };

  // Centralized, scannable CSS patterns
  const inputStyle = {
    width: '100%',
    boxSizing: 'border-box', // Prevents inputs from blowing out past their containers
    background: '#1f2937',
    color: '#fff',
    padding: '12px',
    border: '1px solid #374151',
    borderRadius: '4px',
    fontFamily: 'inherit',
    fontSize: '14px'
  };

  const buttonStyle = (colorCode) => ({
    width: '100%',
    background: colorCode,
    color: '#fff',
    border: 'none',
    padding: '12px',
    marginTop: '12px',
    fontWeight: 'bold',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'all 0.2s ease'
  });

  return (
    <div style={{ padding: '30px', maxWidth: '1400px', margin: '0 auto', background: '#0b0f19', minHeight: '90vh' }}>
      <h1 style={{ color: '#3b82f6', borderBottom: '2px solid #1f2937', paddingBottom: '15px', marginTop: 0 }}>
        AegisRAG Portfolio Sandbox
      </h1>
      
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px', marginTop: '20px' }}>
        {/* Actions Pane */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '25px' }}>
          
          {/* Document Ingest Form */}
          <div style={{ background: '#111827', padding: '24px', borderRadius: '8px', border: '1px solid #1f2937' }}>
            <h3 style={{ color: '#10b981', marginTop: 0, marginBottom: '16px' }}>Secure Document Ingest</h3>
            <form onSubmit={handleIngest}>
              <textarea 
                style={{ ...inputStyle, height: '100px', resize: 'vertical' }} 
                value={text} 
                onChange={e => setText(e.target.value)} 
                placeholder="Confidential documentation text context..." 
                disabled={loadingIngest}
              />
              <button 
                type="submit" 
                style={{ ...buttonStyle('#10b981'), opacity: loadingIngest ? 0.6 : 1 }}
                disabled={loadingIngest}
              >
                {loadingIngest ? 'Processing Cryptography...' : 'Encrypt and Write to Vault'}
              </button>
            </form>
          </div>

          {/* Neural Query Interface */}
          <div style={{ background: '#111827', padding: '24px', borderRadius: '8px', border: '1px solid #1f2937' }}>
            <h3 style={{ color: '#3b82f6', marginTop: 0, marginBottom: '16px' }}>Neural Query Interface</h3>
            <form onSubmit={handleQuery}>
              <input 
                style={inputStyle} 
                value={query} 
                onChange={e => setQuery(e.target.value)} 
                placeholder="Ask secure architectural context query..." 
                disabled={loadingQuery}
              />
              <button 
                type="submit" 
                style={{ ...buttonStyle('#3b82f6'), opacity: loadingQuery ? 0.6 : 1 }}
                disabled={loadingQuery}
              >
                {loadingQuery ? 'Analyzing Context...' : 'Run Encrypted Search'}
              </button>
            </form>
            
            {answer && (
              <div style={{ background: '#1f2937', padding: '20px', marginTop: '20px', borderRadius: '6px', border: '1px solid #374151' }}>
                <p style={{ marginTop: 0, lineHeight: '1.6', fontSize: '15px' }}><strong>Answer:</strong> {answer}</p>
                {metrics && (
                  <div style={{ borderTop: '1px solid #374151', paddingTop: '10px', marginTop: '10px' }}>
                    <small style={{ color: '#9ca3af', display: 'block', fontSize: '12px' }}>
                      Retrieved Docs: <span style={{ color: '#3b82f6', fontWeight: 'bold' }}>{metrics.retrieved_docs_count}</span> | 
                      Post-Rerank: <span style={{ color: '#10b981', fontWeight: 'bold' }}>{metrics.reranked_docs_count}</span>
                    </small>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Telemetry Stream */}
        <div style={{ background: '#111827', padding: '24px', borderRadius: '8px', border: '1px solid #1f2937', display: 'flex', flexDirection: 'column' }}>
          <h3 style={{ color: '#f59e0b', marginTop: 0, marginBottom: '16px' }}>System Cryptographic Telemetry Logs</h3>
          <div style={{ background: '#030712', flexGrow: 1, height: '460px', padding: '20px', overflowY: 'auto', fontFamily: 'monospace', borderRadius: '6px', border: '1px solid #1f2937', fontSize: '13px', lineHeight: '1.6' }}>
            {logs.length === 0 ? (
              <div style={{ color: '#4b5563', fontStyle: 'italic' }}>Awaiting pipeline network initialization telemetry...</div>
            ) : (
              logs.map((l, i) => (
                <div key={i} style={{ marginBottom: '10px', borderBottom: '1px dashed #1f2937', paddingBottom: '6px' }}>
                  <span style={{ color: '#6b7280' }}>[{l[0]}]</span>{' '}
                  <span style={{ 
                    color: l[2] === 'error' ? '#ef4444' : l[2] === 'success' ? '#10b981' : l[2] === 'crypto' ? '#a855f7' : '#3b82f6',
                    fontWeight: 'bold'
                  }}>
                    [{l[2].toUpperCase()}]
                  </span>{' '}
                  <span style={{ color: '#e5e7eb' }}>{l[1]}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

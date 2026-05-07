export default function App() {
  return (
    <main className="toolbar-shell" style={{ position: "relative", zIndex: 10 }}>
      <section className="panel raycast-single">
        <div className="input-wrap only-input">
          <input
            type="text"
            placeholder="输入命令，↑↓ 选择，Enter 执行，Esc 收起"
            autoFocus
            autoComplete="off"
          />
        </div>
      </section>
    </main>
  );
}

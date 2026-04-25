export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ minHeight: '100svh', backgroundColor: 'var(--surface-secondary)' }}>
      {/* Sprint 3+: Header + Sidebar go here */}
      <main style={{ padding: 'var(--space-6)' }}>
        {children}
      </main>
    </div>
  );
}

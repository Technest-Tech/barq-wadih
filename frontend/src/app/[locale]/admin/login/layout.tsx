// Admin login has its own layout — no sidebar/header, no auth guard
export default function AdminLoginLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

import '../layout';

// (public) route group uses the same layout as the main [locale] layout.
// This group is for public-facing pages: ads listing, search, ad detail, etc.
export default function PublicLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}

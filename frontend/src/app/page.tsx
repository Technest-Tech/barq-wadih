import { redirect } from 'next/navigation';

// Root URL — immediately redirect to the default locale (Arabic)
export default function RootPage() {
  redirect('/ar');
}

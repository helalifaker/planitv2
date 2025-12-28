import Link from "next/link";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-8">
      <div className="text-center">
        <h1 className="text-3xl font-bold tracking-tight">Plan-It</h1>
        <p className="mt-2 text-muted">
          FP&A Platform for KSA Community Schools (AEFE)
        </p>
        <div className="mt-8 flex gap-4">
          <Link
            href="/workspace/enrollment"
            className="rounded-md bg-primary-600 px-4 py-2 text-sm font-medium text-white hover:bg-primary-700"
          >
            Open Workspace
          </Link>
        </div>
      </div>
    </div>
  );
}

"use client";

import { Sidebar } from "./sidebar";
import { TopBar } from "./top-bar";

export function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <TopBar />
        <main className="flex-1 overflow-auto bg-slate-50">{children}</main>
      </div>
    </div>
  );
}

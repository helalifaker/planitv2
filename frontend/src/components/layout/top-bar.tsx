"use client";

import { ChevronDown } from "lucide-react";

export function TopBar() {
  return (
    <header className="flex h-14 items-center justify-between border-b border-border bg-white px-6">
      <div className="flex items-center gap-4">
        {/* Scenario Selector */}
        <button className="flex items-center gap-2 rounded-md border border-border bg-white px-3 py-1.5 text-sm font-medium hover:bg-slate-50">
          <span className="text-slate-600">Scenario:</span>
          <span>Base Budget 2024-25</span>
          <ChevronDown className="h-4 w-4 text-slate-400" />
        </button>
      </div>
      <div className="flex items-center gap-4">
        {/* User menu placeholder */}
        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary-100 text-sm font-medium text-primary-700">
          U
        </div>
      </div>
    </header>
  );
}

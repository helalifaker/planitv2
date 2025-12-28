"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Users, Briefcase, DollarSign, LayoutDashboard } from "lucide-react";
import { cn } from "@/lib/utils";

const navigation = [
  {
    name: "Dashboard",
    href: "/workspace",
    icon: LayoutDashboard,
  },
  {
    name: "Enrollment",
    href: "/workspace/enrollment",
    icon: Users,
  },
  {
    name: "Workforce",
    href: "/workspace/workforce",
    icon: Briefcase,
  },
  {
    name: "Financials",
    href: "/workspace/financials",
    icon: DollarSign,
  },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex w-60 flex-col border-r border-border bg-white">
      <div className="flex h-14 items-center border-b border-border px-4">
        <span className="text-lg font-semibold tracking-tight">Plan-It</span>
      </div>
      <nav className="flex-1 space-y-1 px-2 py-4">
        {navigation.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(item.href + "/");
          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                isActive
                  ? "bg-primary-50 text-primary-700"
                  : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
              )}
            >
              <item.icon className="h-4 w-4" />
              {item.name}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}

export default function FinancialsPage() {
  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-border px-6 py-4">
        <h1>Financials</h1>
        <p>P&L and cash flow projections</p>
      </div>
      <div className="flex-1 p-6">
        {/* Grid will be rendered here */}
        <div className="flex h-full items-center justify-center rounded-lg border border-dashed border-border">
          <p className="text-muted">Financials Grid Coming Soon</p>
        </div>
      </div>
    </div>
  );
}

export default function WorkforcePage() {
  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-border px-6 py-4">
        <h1>Workforce</h1>
        <p>DHG calculations and staffing management</p>
      </div>
      <div className="flex-1 p-6">
        {/* Grid will be rendered here */}
        <div className="flex h-full items-center justify-center rounded-lg border border-dashed border-border">
          <p className="text-muted">Workforce Grid Coming Soon</p>
        </div>
      </div>
    </div>
  );
}

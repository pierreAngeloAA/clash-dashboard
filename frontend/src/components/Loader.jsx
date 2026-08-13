export default function Loader({ label = 'Cargando datos...' }) {
  return (
    <div className="flex flex-col items-center justify-center py-20 gap-3 animate-fadeIn">
      <div className="h-10 w-10 rounded-full border-2 border-slate-200 border-t-brand-500 animate-spin" />
      <p className="text-sm text-slate-500">{label}</p>
    </div>
  );
}

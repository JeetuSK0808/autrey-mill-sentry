import { STATUS_LABEL } from "@/lib/rank";
export default function StatusBadge({ status, review }: { status: string; review?: boolean }) {
  return (<>
    <span className={`badge ${status}`}>{STATUS_LABEL[status] ?? status}</span>
    {review && <span className="badge review" style={{ marginLeft: 6 }}>Expert review</span>}
  </>);
}

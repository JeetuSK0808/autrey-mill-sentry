export default function About() {
  return (
    <main className="wrap" style={{ maxWidth: 760 }}>
      <h1>About this dashboard</h1>
      <p>Mill Sentry is a student project by Jeetu SK, built for Autrey Mill Nature Preserve & Heritage Center. Visitors scan plants with the iPhone app; the app identifies the plant on the phone, and when the visitor taps Send the report (photo, location, species guess, patch size, note) is uploaded here for staff to review.</p>
      <h2>What the statuses mean</h2>
      <p><strong>New</strong>: uploaded, not yet looked at. <strong>Expert review</strong>: the app was not sure enough to name the species, so a person should check the photo. <strong>Confirmed</strong>: staff agree it is the invasive named. <strong>Treated</strong>: dealt with; the visitor's app is told on its next check. <strong>Dismissed</strong>: not an invasive, or a duplicate.</p>
      <h2>Privacy</h2>
      <p>Reports carry no name, email or account. Photos are stripped of camera and GPS metadata before upload; the coordinates shown are the ones the visitor's app recorded for the plant. This site has no analytics. Only people with the access code can see reports and photos.</p>
      <h2>Accuracy</h2>
      <p>The on-device model was trained on licensed iNaturalist photos and evaluated on photos from people it never saw. Its numbers, including how often it is wrong, are in the app's About screen and the project's model card. AI suggestion, not a guarantee. Staff make the final call.</p>
      <p className="footnote">Map data © OpenStreetMap contributors (ODbL). Built with Next.js on Vercel's free tier.</p>
    </main>
  );
}

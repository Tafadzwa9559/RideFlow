import { Link } from "react-router-dom";
import content from "../../legal/policies.json";
import "./legal.css";

export default function LegalPage({
  documentId,
}: {
  documentId: "terms" | "privacy";
}) {
  const document = content.documents[documentId];
  return (
    <article
      className="legal-page site-container"
      aria-labelledby="legal-heading"
    >
      <header>
        <p className="legal-kicker">TRIVIA · LEGAL INFORMATION</p>
        <h1 id="legal-heading">{document.title}</h1>
        {content.status !== "published" && (
          <aside role="note" className="legal-review">
            {content.reviewNotice}
          </aside>
        )}
        <p className="legal-version">
          Version: {content.version}
          <br />
          Effective date: {content.effectiveDate ?? "To be confirmed"}
        </p>
        <p>{content.attribution}</p>
        <div className="legal-document-links">
          <Link to="/terms">Terms &amp; Conditions</Link>
          <Link to="/privacy">Privacy Policy</Link>
        </div>
      </header>
      <nav aria-label={`${document.title} sections`} className="legal-contents">
        <h2>Contents</h2>
        <ol>
          {document.sections.map((section) => (
            <li key={section.id}>
              <a href={`#${section.id}`}>{section.title}</a>
            </li>
          ))}
        </ol>
      </nav>
      {document.sections.map((section, index) => (
        <section
          id={section.id}
          key={section.id}
          aria-labelledby={`${section.id}-heading`}
        >
          <h2 id={`${section.id}-heading`}>
            {index + 1}. {section.title}
          </h2>
          {section.paragraphs.map((paragraph) => (
            <p key={paragraph}>{paragraph}</p>
          ))}
        </section>
      ))}
      <p className="legal-end">{content.attribution}</p>
      <a className="legal-top" href="#legal-heading">
        Back to top
      </a>
    </article>
  );
}

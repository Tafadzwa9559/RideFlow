import Photo from "../../components/ui/Photo";
import ScrollReveal from "../../components/common/ScrollReveal";
import { useState, useRef, useEffect } from "react";
import { Link } from "react-router-dom";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import axios from "axios";
import { env } from "../../config/env";
const schema = z.object({
  name: z.string().trim().min(2, "Enter your name.").max(100, "Keep your name under 100 characters."),
  email: z.email("Enter a valid email."),
  topic: z.enum(["General enquiry", "Passenger support", "Driver enquiry"]),
  message: z
    .string()
    .trim()
    .min(20, "Please provide at least 20 characters.")
    .max(3000, "Keep the message under 3,000 characters."),
});
type Fields = z.infer<typeof schema>;
export default function Contact() {
  const [status, setStatus] = useState("");
  const request = useRef<AbortController | null>(null);
  useEffect(() => () => request.current?.abort(), []);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<Fields>({
    resolver: zodResolver(schema),
    defaultValues: { topic: "General enquiry" },
  });
  return (
    <>
      <ScrollReveal
        as="header"
        direction="left"
        className="site-page-hero site-container"
      >
        <span className="site-eyebrow">LET’S KEEP THE CONVERSATION CLEAR</span>
        <h1>Contact & support.</h1>
        <p>
          General questions, passenger support and driver enquiries. Confirmed
          contact channels will appear here when available.
        </p>
      </ScrollReveal>
      <ScrollReveal
        direction="none"
        className="site-section site-container contact-grid"
      >
        <div>
          <Photo name="harare" className="contact-photo" />
          <h2>A question about Trivia?</h2>
          <p>
            Use general enquiries for product questions, passenger support for
            app-related questions, and driver enquiries for onboarding
            information.
          </p>
          {env.supportEmail ? (
            <a className="site-text-link" href={`mailto:${env.supportEmail}`}>
              {env.supportEmail} ↗
            </a>
          ) : (
            <p className="availability-note">
              A public support email or telephone number has not yet been
              configured.
            </p>
          )}
          <p>
            This form is not an emergency channel. Do not send passwords,
            identity documents or payment details.
          </p>
          <Link className="site-text-link" to="/faq">
            Read the FAQs →
          </Link>
        </div>
        <form
          className="contact-form"
          noValidate
          onChange={() => setStatus("")}
          onSubmit={handleSubmit(async (data) => {
            if (!env.contactUrl) {
              setStatus(
                "Message not sent. Contact delivery is not configured. Your draft remains available here.",
              );
              return;
            }
            setStatus("");
            request.current?.abort();
            request.current = new AbortController();
            try {
              await axios.post(env.contactUrl, data, { timeout: 15000, signal: request.current.signal });
              setStatus(
                "The configured contact service accepted your message. A response time is not guaranteed.",
              );
              reset();
            } catch (error) {
              if (axios.isCancel(error)) return;
              setStatus(
                "Your message could not be sent. Please try again later or use the configured contact alternative.",
              );
            }
          })}
        >
          <h2>Send an enquiry</h2>
          <p className="availability-note">
            {env.contactUrl
              ? "Messages use the configured contact service."
              : "Contact delivery is not configured. You can prepare and validate a draft; it will not be delivered."}
          </p>
          {(
            [
              ["name", "Your name"],
              ["email", "Email address"],
            ] as const
          ).map(([name, label]) => (
            <label className="field" key={name}>
              {label}
              <input
                aria-label={label}
                {...register(name)}
                type={name === "email" ? "email" : "text"}
                autoComplete={name}
                aria-invalid={!!errors[name]}
                aria-describedby={errors[name] ? `contact-${name}-error` : undefined}
                maxLength={name === "name" ? 100 : 254}
                required
              />
              {errors[name] && (
                <span id={`contact-${name}-error`} className="field-error" role="alert">
                  {errors[name]?.message}
                </span>
              )}
            </label>
          ))}
          <label className="field">
            Enquiry type
            <select {...register("topic")}>
              <option>General enquiry</option>
              <option>Passenger support</option>
              <option>Driver enquiry</option>
            </select>
          </label>
          <label className="field">
            Message
            <textarea
              aria-label="Message"
              rows={6}
              {...register("message")}
              aria-invalid={!!errors.message}
              aria-describedby={errors.message ? "contact-message-error" : "contact-message-help"}
              maxLength={3000}
              required
            />
            <small id="contact-message-help">20–3,000 characters. Please omit sensitive personal details.</small>
            {errors.message && (
              <span id="contact-message-error" className="field-error" role="alert">
                {errors.message.message}
              </span>
            )}
          </label>
          <button className="site-button" disabled={isSubmitting}>
            {isSubmitting
              ? "Please wait…"
              : env.contactUrl
                ? "Send enquiry"
                : "Validate enquiry draft"}
          </button>
          {status && (
            <p className="availability-note" role="status">
              {status}
            </p>
          )}
        </form>
      </ScrollReveal>
    </>
  );
}

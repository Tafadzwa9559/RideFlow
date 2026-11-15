import ScrollReveal from "../common/ScrollReveal";
import { ArrowUpRight, Smartphone } from "lucide-react";
import { env } from "../../config/env";
import {
  useDevicePlatform,
  type Platform,
} from "../../hooks/useDevicePlatform";
export default function AppDownload() {
  const { selected, setSelected } = useDevicePlatform();
  const options =
    selected === "desktop"
      ? (["android", "ios"] as const)
      : ([selected] as const);
  return (
    <div className="app-download">
      <label className="platform-choice">
        Choose your platform
        <select
          aria-label="Download platform"
          value={selected}
          onChange={(e) => setSelected(e.target.value as Platform)}
        >
          <option value="desktop">Both platforms</option>
          <option value="android">Android</option>
          <option value="ios">iPhone / iOS</option>
        </select>
      </label>
      <div className="download-options">
        {options.map((platform, index) => {
          const android = platform === "android";
          const url = android ? env.androidUrl || env.apkUrl : env.iosUrl;
          const label = android
            ? "Download for Android"
            : "Download for iPhone";
          return (
            <ScrollReveal
              as="div"
              delay={index * 0.08}
              distance={24}
              className="download-option"
              key={platform}
            >
              {url ? (
                <a
                  className="download-button"
                  href={url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Smartphone size={22} />
                  <span>
                    <small>
                      {android
                        ? env.androidUrl
                          ? "GOOGLE PLAY"
                          : "OFFICIAL APK"
                        : "APP STORE"}
                    </small>
                    {label}
                  </span>
                  <ArrowUpRight size={18} />
                </a>
              ) : (
                <button
                  className="download-button"
                  disabled
                  aria-label={`${label} — Coming soon`}
                >
                  <Smartphone size={22} />
                  <span>
                    <small>COMING SOON</small>
                    {label}
                  </span>
                </button>
              )}
              <small>
                {url
                  ? android && !env.androidUrl
                    ? "Direct APK distribution · Android only"
                    : "Opens the configured official store listing"
                  : "An official release link has not been announced."}
              </small>
            </ScrollReveal>
          );
        })}
      </div>
      <p className="download-note">
        One Trivia app for passengers and drivers. Platform detection is a
        suggestion; you can always choose another platform.
      </p>
    </div>
  );
}

import { useEffect, useState } from "react";
import {
  CircleMarker,
  MapContainer,
  Polyline,
  TileLayer,
  Tooltip,
  useMap,
  useMapEvents,
} from "react-leaflet";
import { LocateFixed } from "lucide-react";
import { toast } from "sonner";
import "leaflet/dist/leaflet.css";
import type { Location } from "../../types/domain";
import { routeFixture } from "../../services/mock";
function MapController({
  pickup,
  destination,
  onSelect,
}: {
  pickup: Location;
  destination: Location;
  onSelect?: (place: Location) => void;
}) {
  const map = useMap();
  useEffect(() => {
    map.fitBounds(
      [
        [pickup.lat, pickup.lng],
        [destination.lat, destination.lng],
      ],
      { padding: [55, 55], maxZoom: 14 },
    );
  }, [map, pickup, destination]);
  useMapEvents({
    click: (e) =>
      onSelect?.({
        name: `Map pin (${e.latlng.lat.toFixed(4)}, ${e.latlng.lng.toFixed(4)})`,
        lat: e.latlng.lat,
        lng: e.latlng.lng,
      }),
  });
  return null;
}
export default function RideMap({
  pickup,
  destination,
  onSelect,
  showRoute = false,
}: {
  pickup: Location;
  destination: Location;
  onSelect?: (place: Location) => void;
  showRoute?: boolean;
}) {
  const [tilesFailed, setTilesFailed] = useState(false);
  const fixture =
    pickup.name.startsWith("Avondale") &&
    destination.name.startsWith("Eastgate");
  function locate() {
    if (!navigator.geolocation) {
      toast.error("Location is unavailable. Please select a place manually.");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (p) =>
        onSelect?.({
          name: "Your current location",
          lat: p.coords.latitude,
          lng: p.coords.longitude,
        }),
      () =>
        toast.error(
          "Location unavailable. Choose a saved place or select a point on the map.",
        ),
      { timeout: 10000 },
    );
  }
  return (
    <div className="ride-map">
      <MapContainer
        center={[-17.812, 31.045]}
        zoom={13}
        scrollWheelZoom={false}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          eventHandlers={{ tileerror: () => setTilesFailed(true) }}
        />
        <MapController
          pickup={pickup}
          destination={destination}
          onSelect={onSelect}
        />
        <CircleMarker
          center={[pickup.lat, pickup.lng]}
          radius={9}
          pathOptions={{
            color: "#fff",
            weight: 4,
            fillColor: "#10b981",
            fillOpacity: 1,
          }}
        >
          <Tooltip permanent direction="top">
            Pickup
          </Tooltip>
        </CircleMarker>
        <CircleMarker
          center={[destination.lat, destination.lng]}
          radius={9}
          pathOptions={{
            color: "#fff",
            weight: 4,
            fillColor: "#171717",
            fillOpacity: 1,
          }}
        >
          <Tooltip permanent direction="top">
            Destination
          </Tooltip>
        </CircleMarker>
        {showRoute && fixture && (
          <Polyline
            positions={routeFixture.points}
            pathOptions={{ color: "#10b981", weight: 5, dashArray: "8 7" }}
          />
        )}
      </MapContainer>
      <span className="map-label">
        {tilesFailed
          ? "Map tiles unavailable · use location selectors"
          : "OpenStreetMap · No live vehicles"}
      </span>
      {onSelect && (
        <button
          className="map-locate"
          aria-label="Use my current location"
          onClick={locate}
        >
          <LocateFixed size={19} />
        </button>
      )}
      {showRoute && fixture && (
        <span className="map-route-note">
          Schematic demo route · not navigation
        </span>
      )}
    </div>
  );
}

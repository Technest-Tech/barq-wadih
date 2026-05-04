'use client';

// Client-only Leaflet wrapper. Loaded by MapStep via next/dynamic with
// ssr: false so the `window` access never runs on the server.

import 'leaflet/dist/leaflet.css';
import { MapContainer, Marker, TileLayer, useMapEvents } from 'react-leaflet';
import { useEffect, useMemo } from 'react';
import L from 'leaflet';

// Fix Leaflet's default-icon paths (the bundler strips them otherwise).
const ICON = new L.Icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
});

type Props = {
  center: [number, number];
  marker: [number, number] | null;
  onChange: (lat: number, lng: number) => void;
};

function ClickHandler({ onChange }: { onChange: Props['onChange'] }) {
  useMapEvents({
    click: (e) => onChange(e.latlng.lat, e.latlng.lng),
  });
  return null;
}

export function MapStepLeaflet({ center, marker, onChange }: Props) {
  const key = useMemo(() => `${center[0]}-${center[1]}`, [center]);

  // No-op effect kept to highlight that Leaflet handles its own DOM teardown
  // when the dynamic import remounts.
  useEffect(() => () => undefined, []);

  return (
    <MapContainer key={key} center={center} zoom={13} scrollWheelZoom>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <ClickHandler onChange={onChange} />
      {marker && (
        <Marker
          position={marker}
          icon={ICON}
          draggable
          eventHandlers={{
            dragend: (e) => {
              const ll = (e.target as L.Marker).getLatLng();
              onChange(ll.lat, ll.lng);
            },
          }}
        />
      )}
    </MapContainer>
  );
}

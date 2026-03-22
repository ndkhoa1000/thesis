// Type declaration for platform-specific ParkingMap component.
// Metro bundler resolves ParkingMap.native.tsx or ParkingMap.web.tsx
// depending on the platform. TypeScript needs this stub to find the module.
declare module '@/components/ParkingMap' {
  import { ComponentType } from 'react';
  const ParkingMap: ComponentType;
  export default ParkingMap;
}

// Type declaration for mapbox-gl CSS import (web-only, safely ignored on native)
declare module 'mapbox-gl/dist/mapbox-gl.css' {
  const content: string;
  export default content;
}

// react-map-gl v8 uses subpath exports: 'react-map-gl/mapbox' for Mapbox GL
declare module 'react-map-gl/mapbox' {
  import { ComponentType, ReactNode } from 'react';

  export interface ViewState {
    longitude: number;
    latitude: number;
    zoom: number;
  }

  export interface MarkerProps {
    longitude: number;
    latitude: number;
    onClick?: (e: any) => void;
    offset?: number | [number, number];
    children?: ReactNode;
  }

  export interface PopupProps {
    longitude: number;
    latitude: number;
    anchor?: string;
    onClose?: () => void;
    closeOnClick?: boolean;
    offset?: number;
    children?: ReactNode;
  }

  export interface MapProps {
    mapboxAccessToken: string;
    initialViewState?: Partial<ViewState>;
    style?: any;
    mapStyle?: string;
    children?: ReactNode;
    [key: string]: any;
  }

  const Map: ComponentType<MapProps>;
  export const Marker: ComponentType<MarkerProps>;
  export const Popup: ComponentType<PopupProps>;
  export default Map;
}

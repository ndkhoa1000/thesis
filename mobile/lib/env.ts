const mapboxPublicToken = process.env.EXPO_PUBLIC_MAPBOX_TOKEN?.trim() ?? '';

export const env = {
  mapboxPublicToken,
};

export const hasMapboxPublicToken = mapboxPublicToken.length > 0;

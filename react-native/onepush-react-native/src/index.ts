// Ad Venture One Push — React Native köprüsü. Yüzey çekirdekle birebir
// (docs/ONE_PUSH_PLANI.md bölüm 4); köprü push işi yapmaz, yalnız iletir.
import { NativeModules, Platform } from 'react-native';

export type OnePushEnvironment = 'auto' | 'debug' | 'test' | 'production';

export interface OnePushConfig {
  appKey: string;
  endpoint?: string;
  environment?: OnePushEnvironment;
  guestMode?: boolean;
}

export interface OnePushInboxItem {
  pushId: string;
  title: string | null;
  body: string | null;
  deepLink: string | null;
  receivedAt: number; // ms since epoch
  read: boolean;
}

export const PAYLOAD_ID_KEY = 'one_push_id';

type Data = Record<string, unknown> | null | undefined;

const Native = NativeModules.OnePushModule as {
  start(cfg: Required<Pick<OnePushConfig, 'appKey'>> & OnePushConfig): Promise<void>;
  setPushToken(t: string): Promise<void>;
  setAppInstanceId(id: string): Promise<void>;
  setUserId(id: string | null): Promise<void>;
  setUserAttribute(k: string, v: string | null): Promise<void>;
  addTag(t: string): Promise<void>;
  removeTag(t: string): Promise<void>;
  setConsent(g: boolean): Promise<void>;
  track(e: string, p: Record<string, string>): Promise<void>;
  flush(): Promise<void>;
  handle(d: Record<string, string>): Promise<boolean>;
  didOpen(d: Record<string, string>): Promise<boolean>;
  inbox(limit: number): Promise<OnePushInboxItem[]>;
  markInboxRead(id: string): Promise<void>;
  requestPermission(): Promise<boolean>;
  refreshPermissionStatus(): Promise<void>;
} | undefined;

function native() {
  if (!Native) {
    throw new Error(`OnePushModule native module not linked (${Platform.OS}). Rebuild the app after adding @adventure/onepush-react-native.`);
  }
  return Native;
}

function strings(d: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const k of Object.keys(d)) out[k] = d[k] == null ? '' : String(d[k]);
  return out;
}

/** Payload bizim mi? Saf JS; natife gitmez. */
export function isOnePushMessage(data: Data): boolean {
  const v = data?.[PAYLOAD_ID_KEY];
  return typeof v === 'string' && v.trim().length > 0;
}

export const OnePush = {
  start: (cfg: OnePushConfig) => native().start({ environment: 'auto', guestMode: true, ...cfg }),
  setPushToken: (t: string) => native().setPushToken(t),
  setAppInstanceId: (id: string) => native().setAppInstanceId(id),
  setUserId: (id: string) => native().setUserId(id),
  clearUserId: () => native().setUserId(null),
  setUserAttribute: (k: string, v: string | null) => native().setUserAttribute(k, v),
  addTag: (t: string) => native().addTag(t),
  removeTag: (t: string) => native().removeTag(t),
  setConsent: (g: boolean) => native().setConsent(g),
  track: (e: string, p: Record<string, string> = {}) => native().track(e, p),
  flush: () => native().flush(),
  isOnePushMessage,
  /** Bildirim ALINDI (`@react-native-firebase/messaging` `message.data`). Bizim değilse false, natife gitmez. */
  handle: async (data: Data) => (isOnePushMessage(data) ? native().handle(strings(data as Record<string, unknown>)) : false),
  /** Kullanıcı bildirime DOKUNDU. */
  didOpen: async (data: Data) => (isOnePushMessage(data) ? native().didOpen(strings(data as Record<string, unknown>)) : false),
  inbox: (limit = 50) => native().inbox(limit),
  markInboxRead: (id: string) => native().markInboxRead(id),
  requestPermission: () => native().requestPermission(),
  refreshPermissionStatus: () => native().refreshPermissionStatus(),
};

export default OnePush;

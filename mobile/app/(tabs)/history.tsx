import { View, Text } from 'react-native';

export default function HistoryScreen() {
  return (
    <View className="flex-1 bg-slate-50 dark:bg-slate-900 items-center justify-center">
      <Text className="text-5xl mb-3">🕐</Text>
      <Text className="text-lg font-semibold text-slate-800 dark:text-slate-200">
        Lịch sử gửi xe
      </Text>
      <Text className="text-sm text-slate-500 dark:text-slate-400 mt-1">
        Chưa có lịch sử
      </Text>
    </View>
  );
}

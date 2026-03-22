import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { useAuth } from '@/contexts/AuthContext';

export default function HomeScreen() {
  const { user } = useAuth();

  return (
    <ScrollView className="flex-1 bg-slate-50 dark:bg-slate-900">
      <View className="px-5 pt-6 pb-4">
        {/* Greeting */}
        <Text className="text-2xl font-bold text-slate-900 dark:text-white">
          Xin chào! 👋
        </Text>
        <Text className="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {user?.email}
        </Text>
      </View>

      {/* Quick Actions */}
      <View className="px-5 mt-4">
        <Text className="text-lg font-semibold text-slate-800 dark:text-slate-200 mb-3">
          Thao tác nhanh
        </Text>
        <View className="flex-row gap-3">
          <TouchableOpacity className="flex-1 bg-primary-500 rounded-2xl p-4 items-center">
            <Text className="text-3xl mb-1">🗺️</Text>
            <Text className="text-white font-medium text-sm">Tìm bãi xe</Text>
          </TouchableOpacity>
          <TouchableOpacity className="flex-1 bg-white dark:bg-slate-800 rounded-2xl p-4 items-center border border-slate-200 dark:border-slate-700">
            <Text className="text-3xl mb-1">📋</Text>
            <Text className="text-slate-700 dark:text-slate-300 font-medium text-sm">
              Đặt trước
            </Text>
          </TouchableOpacity>
          <TouchableOpacity className="flex-1 bg-white dark:bg-slate-800 rounded-2xl p-4 items-center border border-slate-200 dark:border-slate-700">
            <Text className="text-3xl mb-1">🎫</Text>
            <Text className="text-slate-700 dark:text-slate-300 font-medium text-sm">
              Vé tháng
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Placeholder sections */}
      <View className="px-5 mt-6">
        <Text className="text-lg font-semibold text-slate-800 dark:text-slate-200 mb-3">
          Bãi xe gần đây
        </Text>
        <View className="bg-white dark:bg-slate-800 rounded-2xl p-6 items-center border border-slate-200 dark:border-slate-700">
          <Text className="text-4xl mb-2">📍</Text>
          <Text className="text-slate-500 dark:text-slate-400 text-center">
            Bật vị trí để xem bãi xe gần bạn
          </Text>
        </View>
      </View>

      <View className="h-8" />
    </ScrollView>
  );
}

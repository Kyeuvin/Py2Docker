import time
import datetime

def main():
    print("Task4 后台服务启动...")
    print(f"启动时间: {datetime.datetime.now()}")
    
    while True:
        try:
            # 这里写你的业务逻辑
            current_time = datetime.datetime.now()
            print(f"[{current_time}] Task4 正在运行...")
            
            # 模拟处理工作
            time.sleep(30)  # 每30秒执行一次
            
        except KeyboardInterrupt:
            print("Task4 收到停止信号，正在退出...")
            break
        except Exception as e:
            print(f"Task4 发生错误: {e}")
            time.sleep(5)  # 错误后等待5秒再重试

if __name__ == "__main__":
    main()
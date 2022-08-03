--
-- Mehdi Ben Djedidia 03/08/2022 --
--
-- Démo du gyroscope mpu-9250
-- et d'un écran oled sh1106
--
-- variante : l'écran Oled 1 et le MPU sont branchés en // sur le même bus I2C 1
-- et sur les mêmes pin et ça fonctionne
-- par contre ça ne fonctionne pas sur des pins différentes pourtant identifiées
-- par le même n° I2C sur le board STM32_F446RE

with Last_Chance_Handler;
pragma Unreferenced (Last_Chance_Handler);
--  The "last chance handler" is the user-defined routine that is called when
--  an exception is propagated. We need it in the executable, therefore it
--  must be somewhere in the closure of the context clauses.

with STM32.Board; use STM32.Board;
with STM32.Setup;

with Ada.Real_Time; use Ada.Real_Time;

with SH1106; use SH1106; 		-- oled screen (i2c)
with MPU92XX; use MPU92XX; 	-- gyroscope (i2c)

with STM32.Device; use STM32.Device;

with Ravenscar_Time;

with HAL.Bitmap;

with Bitmapped_Drawing;
with BMP_Fonts;
with Interfaces; use Interfaces;

procedure Main is
	Period       : constant Time_Span := Milliseconds (500);
	Next_Release : Time := Clock;

	Oled1106_1      : SH1106_Screen (Buffer_Size_In_Byte => (128 * 64) / 8,
											 Width               => 128,
											 Height              => 64,
											 Port                => I2C_1'Access,
											 RST                 => PA0'Access, -- reset de l'écran ; PA0 choix arbitraire car pas utilisé mais obligatoire
											 Time                => Ravenscar_Time.Delays);
	-- second oled sur I2C_2
	Oled1106_2      : SH1106_Screen (Buffer_Size_In_Byte => (128 * 64) / 8,
											 Width               => 128,
											 Height              => 64,
											 Port                => I2C_2'Access,
											 RST                 => PA0'Access, -- reset de l'écran ; PA0 choix arbitraire car pas utilisé mais obligatoire
											 Time                => Ravenscar_Time.Delays);

	-- MPU9250 sur I2C 1 comme l'écran Oled 1
	Gyro : MPU92XX_Device (Port        => I2C_1'Access,
								I2C_AD0_Pin => Low, 	-- Pin ADO ici sur GND (Low) : Low/High to change I2C address
								Time        => Ravenscar_Time.Delays);


	-- valeurs lues sur le MPU92XX
	Acc_X, Acc_Y, Acc_Z    : Integer_16;
	Gyro_X, Gyro_Y, Gyro_Z : Integer_16;

	Angle_X, Angle_Y       : Float;

	Degre                  : constant := 180.0 / 3.1415; -- pour la conversion de rd en degré


	-- le profil Ravenscar ne permet pas l'utilisation de Float_IO
	-- mais on peut utiliser 'Img sur un type fixed point
	-- cf https://github.com/AdaCore/Ada_Drivers_Library/issues/294
	type Fixed_Type_Affichage is delta 0.1 digits 10;
	Angle_X_Fixed, Angle_Y_Fixed, Temp_Fixed : Fixed_Type_Affichage;

begin

	-- initialiser la led utilisateur verte
	STM32.Board.Initialize_LEDs;
	STM32.Board.Turn_On (Green_LED);

	-- initialisation du port I2C 1 pour l'écran oled sh1106 en i2c
	STM32.Setup.Setup_I2C_Master  (Port        => I2C_1,
										  SDA         => PB9,
										  SCL         => PB8,
										  SDA_AF      => GPIO_AF_I2C1_4,
										  SCL_AF      => GPIO_AF_I2C1_4,
										  Clock_Speed => 100_000); -- 100 KHz

	-- initialisation du port I2C 2 pour un 2nd écran oled sh1106 en i2c
	STM32.Setup.Setup_I2C_Master  (Port        => I2C_2,
										  SDA         => PB3,
										  SCL         => PB10,
										  SDA_AF      => GPIO_AF_I2C2_4,
										  SCL_AF      => GPIO_AF_I2C2_4,
										  Clock_Speed => 100_000); -- 100 KHz

	-- initialisation des écrans oled sh1106
	Oled1106_1.Initialize;
	Oled1106_1.Initialize_Layer;
	Oled1106_1.Turn_On;

	Oled1106_2.Initialize;
	Oled1106_2.Initialize_Layer;
	Oled1106_2.Turn_On;

	-- clear screen
	Oled1106_1.Hidden_Buffer.Set_Source (HAL.Bitmap.Black);
	Oled1106_1.Hidden_Buffer.Fill;

	Oled1106_2.Hidden_Buffer.Set_Source (HAL.Bitmap.Black);
	Oled1106_2.Hidden_Buffer.Fill;

	-- initialisation du port I2C 1 pour l'accès au MPU92XX en i2c sur PB8 et PB9 comme Oled 1
	STM32.Setup.Setup_I2C_Master  (Port        => I2C_1,
										  SDA         => PB9,
										  SCL         => PB8,
										  SDA_AF      => GPIO_AF_I2C1_4,
										  SCL_AF      => GPIO_AF_I2C1_4,
										  Clock_Speed => 100_000); -- Le MPU9250 peut échanger à 400 KHz
	-- nb : on peut mettre 400_000 (400 KHz) et ça fonctionne mais à 100 KHz (fréquence de l'oled)

	-- initialisation du MPU92XX
	MPU92XX_Init (Device => Gyro);

	-- enable the temperature sensor
	MPU92XX_Set_Temp_Sensor_Enabled (Device => Gyro,
											 Value  => True);

	Bitmapped_Drawing.Draw_String (Oled1106_1.Hidden_Buffer.all,
										  Start      => (0, 0),
										  Msg        => "OLED 1",
										  Font       => BMP_Fonts.Font8x8,
										  Foreground => HAL.Bitmap.White,
										  Background => HAL.Bitmap.Black);
	-- test du MPU92XX
	if MPU92XX_Test (Device => Gyro) then
		Bitmapped_Drawing.Draw_String (Oled1106_1.Hidden_Buffer.all,
											Start      => (0, 10),
											Msg        => "DEVICE OK",
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);
	else
		Bitmapped_Drawing.Draw_String (Oled1106_1.Hidden_Buffer.all,
											Start      => (0, 10),
											Msg        => "DEVICE KO",
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.Black,
											Background => HAL.Bitmap.White);
	end if;


	-- afficher l'id du device
	Bitmapped_Drawing.Draw_String (Oled1106_1.Hidden_Buffer.all,
										  Start      => (0, 20),
										  Msg        => "ID " & MPU92XX_Who_Am_I (Gyro)'Img,
										  Font       => BMP_Fonts.Font8x8,
										  Foreground => HAL.Bitmap.White,
										  Background => HAL.Bitmap.Black);

	Oled1106_1.Update_Layer;

	--  afficher sur oled 2
	Bitmapped_Drawing.Draw_String (Oled1106_2.Hidden_Buffer.all,
										  Start      => (0, 0),
										  Msg        => "OLED 2",
										  Font       => BMP_Fonts.Font8x8,
										  Foreground => HAL.Bitmap.White,
										  Background => HAL.Bitmap.Black);

	Oled1106_2.Update_Layer;


	STM32.Board.Turn_Off (Green_LED);

	loop
		STM32.Board.Toggle (Green_LED);


		-- effacer la zone des coordonnées avant un nouvel affichage
		Oled1106_1.Hidden_Buffer.Set_Source (HAL.Bitmap.Black);
		Oled1106_1.Hidden_Buffer.Fill_Rect (Area => (Position => (0, 30),
															  Width    => 128,
															  Height   => 30));

		MPU92XX_Get_Motion_6 (Device => Gyro,
								Acc_X  => Acc_X,
								Acc_Y  => Acc_Y,
								Acc_Z  => Acc_Z,
								Gyro_X => Gyro_X,
								Gyro_Y => Gyro_Y,
								Gyro_Z => Gyro_Z);

		Compute_Angles (Acc_X   => Float (Acc_X),
						Acc_Y   => Float (Acc_Y),
						Acc_Z   => Float (Acc_Z),
						Angle_X => Angle_X,
						Angle_Y => Angle_Y);

		-- conversion en degrés et en fixed point type pour l'affichage
		Angle_X_Fixed := Fixed_Type_Affichage ( Angle_X * Degre);
		Angle_Y_Fixed := Fixed_Type_Affichage (Angle_Y * Degre);

		Bitmapped_Drawing.Draw_String (Oled1106_1.Hidden_Buffer.all,
											Start      => (0, 30),
											Msg        => "X" & Angle_X_Fixed'Image,
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);

		Bitmapped_Drawing.Draw_String (Oled1106_1.Hidden_Buffer.all,
											Start      => (0, 40),
											Msg        => "Y" & Angle_Y_Fixed'Image,
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);


		-- afficher la température
		Temp_Fixed := Fixed_Type_Affichage ( MPU92XX_Get_Temperature (Gyro));
		Bitmapped_Drawing.Draw_String (Oled1106_2.Hidden_Buffer.all,
											Start      => (0, 10),
											Msg        => "TEMP" & Temp_Fixed'Img,
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);



		-- mise à jour de l'affichage
		Oled1106_1.Update_Layer;
		Oled1106_2.Update_Layer;

		Next_Release := Next_Release + Period;
		delay until Next_Release;
	end loop;
end Main;
